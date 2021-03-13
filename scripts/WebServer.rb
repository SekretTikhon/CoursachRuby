#require 'tempfile'
#require 'sinatra'
#require 'erb'
#require 'sqlite3'
#require 'pathname'
#require 'logger'


configure do
  enable :sessions
  register Config

  #set :root implicity
  set :logger, Logger.new(STDOUT)
  set :views, "#{settings.root}/views"
  set :no_auth_neededs, ['/login']
  set :db_codes_columns, Settings.db.table.columns.map { |column| column.name }

  require "#{settings.root}/scripts/ZipGenerator.rb"

  TimeFormat = '%H:%M %d/%m/%y'
end

before do
  redirect to ('/login') unless
    are_login or
    settings.no_auth_neededs.include?(request.path_info)
end

get '/' do
  erb :index
end

get '/login' do
  erb :login if are_login

  params = request.env['rack.request.query_hash']
  code = params["code"]
  login_with_code code

  erb :login
end

get '/fs' do
  session['cur_path'] = session['homepath']
  redirect_to_cur_path
end

get '/fs*' do
  puts Settings.param
  #logger.info 'its logger message'
  path = params['splat'][0]

  if !File.exist?(path)
    puts 'path ' + path + ' not exists!' #todo print message
    redirect_to_cur_path
  end
  if File.file?(path)
    #puts path + ' is file.'
    send_file(path, :disposition => 'attachment', :type => 'Application/octet-stream')
    redirect_to_cur_path
  end
  if !File.directory?(path)
    puts path + ' is not directory.' #todo print message
    redirect_to_cur_path
  end

  #correct path
  path = path + '/' if path[-1] != '/'

  #перенаправление если нет прав
  redirect_to_cur_path if !system("sudo -u #{session['user']} [ -r #{path} ]") #todo print error message
  
  #переменные для шаблона
  @directoryes, @files = parse_dirs_files(path)
  @fullpath_map = get_fullpath_map(path)

  session['cur_path'] = path
  erb :files
end

get '/download' do
  filenames = params['filenames'].split(',')

  if filenames
    download_files(filenames)
  end

  redirect_to_cur_path
end

get '/upload' do
  @default_path = session['cur_path']

  erb :upload
end

post '/upload' do
  upload_file

  redirect_to_cur_path
end

get '/cat' do
  send_file 'cat.jpeg'
end

get '/error' do
  halt 401, 'go away!'
end

def redirect_to_cur_path 
  redirect to ('/fs' + session['cur_path'])
end

def parse_dirs_files (path)
  directoryes = []
  files = []

  Dir.children(path).sort.each do |elem|
    fullpath = path + elem
    ref = "/fs" + fullpath
    changes = File.ctime(fullpath).strftime(TimeFormat)
    elem = {name:elem, path: fullpath, href:ref, changes:changes}
    if File.directory?(fullpath)
      directoryes << elem
    elsif File.file?(fullpath)
      files << elem
    end
  end
  return directoryes, files
end

def get_fullpath_map (path)
  map = []
  ref = '/fs'
  path.split('/').each do |elem|
    val = elem + '/'
    ref += val
    map << {name:val, href:ref}
  end
  map << {name:'/', href:'/fs/'} if path == '/'
  return map
end

def download_files (filenames)
  puts filenames
  dir_path = File.dirname(filenames[0])
  filenames = filenames.map {|filename| File.basename(filename)}

  zip_path = Tempfile.new(['', '.zip'])
  zip_file = ZipFileGenerator.new(dir_path, filenames, zip_path)
  zip_file.write()

  send_file(zip_path, :disposition => 'attachment', :type => 'Application/octet-stream')

  zip_path.unlink()
end

def upload_file
  tempfile = params['file'][:tempfile]
  filename = params['file'][:filename]
  path = params['path']
  FileUtils.copy(tempfile.path, path + filename)
end

def are_login
  session['login']
end

def db_execute comand
  db = SQLite3::Database.open Settings.db.path
  res = db.execute comand
  db.close if db
  return res
end

def login_with_code code
  #request to db
  row = db_execute "
    SELECT #{settings.db_codes_columns.join(', ')}
    FROM #{Settings.db.table.name}
    WHERE code = '#{code}'"

  #check that code found
  if row == []
    @error = "the code not found"
    return
  end
  row = row[-1] #becase res is array of rows

  #check that the code already never used
  already_used = row[settings.db_codes_columns.index('already_used')]
  if already_used != 0
    @error = "the code already used"
    return
  end

  #check that the code not expired
  valid_until = row[settings.db_codes_columns.index('valid_until')]
  now_timestamp = `date +%s`.to_i
  if valid_until <= now_timestamp
    @error = "the code expired"
    return
  end

  #if we are here, then the code is valid and not expired
  session['user'] = row[settings.db_codes_columns.index('user')]
  session['code'] = row[settings.db_codes_columns.index('code')]
  session['homepath'] = (`getent passwd #{session['user']}`).split(":")[5]
  session['login'] = true

  #update
  db_execute "
    UPDATE #{Settings.db.table.name}
    SET 'already_used' = 1
    WHERE code = '#{code}'"

end

def check_login
  redirect to ('/') if !are_login
end