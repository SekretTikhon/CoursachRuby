require "tempfile"
require "sinatra"
require "erb"
require "sqlite3"
require "./ZipGenerator.rb"

enable :sessions
set :root, '..'
set :views, '../views'
set :no_auth_neededs, ['/login']

set :db_codes_db_path, '../db/base.db'
set :db_codes_table_name, 'Codes'
set :db_codes_select_columns, 'user, code, generated, valid_until, already_used'
set :db_codes_indexof_user, 0
set :db_codes_indexof_code, 1
set :db_codes_indexof_generated, 2
set :db_codes_indexof_valid_until, 3
set :db_codes_indexof_already_used, 4

TimeFormat = '%H:%M %d/%m/%y'

cur_path = nil

info = nil

before do
  redirect to ('/login') unless
    are_login or
    settings.no_auth_neededs.include?(request.path_info)
end

get '/' do
  ###@login = session['login']
  erb :index
end

get '/login' do
  erb :login if are_login

  params = request.env['rack.request.query_hash']
  code = params["code"]
  login_with_code code

  erb :login
  ###redirect to ('/') if are_login
  ###params = request.env['rack.request.query_hash']
  ###code = params["code"]
  ###if code == nil
  ###  erb :login
  ###else
  ###  login_with_code code
  ###  redirect to ('/') if are_login
  ###  erb :login
  ###end
end

get '/fs' do
  ###check_login
  cur_path = session['homepath'] #home_path
  redirect to ('/fs' + cur_path)
end

get '/fs*' do
  ###check_login
  param = params['splat'][0]

  if !File.exist?(param)
    puts 'path ' + param + ' not exists!'
    redirect to ('/fs' + cur_path)
  elsif File.file?(param)
    puts param + ' is file.'
    redirect to ('/fs' + cur_path)
  elsif File.directory?(param)
    redirect to ('/fs' + param + '/') if param[-1] != '/'
    @fullpath = param
    @user = session['user']

    command = "sudo -u " + @user + " ls -a " + @fullpath

    ## $?.exitstatus || popen

    #перенаправление если нет прав
    redirect to ('/fs' + cur_path) if !system(command) # если не получилось то значит нет прав (наверно)
    
    result = `#{command}`
    list = result.to_s.split("\n").sort
    @directoryes, @files = get_dirs_files(@fullpath, list)
    @fullpath_map = get_fullpath_map(@fullpath)

    cur_path = @fullpath
    erb :files
  end
end

get '/download' do
  filenames = params['filenames'].split(',')

  if filenames
    download_files(filenames)
  end

  redirect to ('/fs' + cur_path)
end

get '/upload' do
  @default_path = cur_path

  erb :upload
end

post '/upload' do
  upload_file

  redirect to ('/fs' + cur_path)
end

get '/cat' do
  send_file 'cat.jpeg'
end

get '/fs/back' do
  check_login
  Dir.chdir('..')
  redirect to ('/fs' + cur_path)
end

get '/error' do
  halt 401, 'go away!'
end

def get_dirs_files (path, list)
  directoryes = []
  files = []
  #Dir.entries('.').sort.each do |elem|
  list.each do |elem|
    fullpath = path + elem
    if File.directory?(fullpath)
      next if elem == '.' || elem == '..'
      #next if fullpath == '/..' #path == '/' && elem == '..'
      ref = "/fs" + fullpath + "/"
      changes = File.ctime(fullpath).strftime(TimeFormat)
      directoryes << {name:elem, path: fullpath, href:ref, changes:changes}
    elsif File.file?(fullpath)
      ref = "/fs" + fullpath
      changes = File.ctime(fullpath).strftime(TimeFormat)
      files << {name:elem, path: fullpath, href:ref, changes:changes}
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
  db = SQLite3::Database.open settings.db_codes_db_path
  res = db.execute comand
  db.close if db
  return res
end

def login_with_code code
  #request to db
  row = db_execute "
    SELECT #{settings.db_codes_select_columns}
    FROM #{settings.db_codes_table_name}
    WHERE code = '#{code}'"

  #check that code found
  if row == []
    @error = "the code not found"
    return
  end
  row = row[-1] #becase res is array of rows

  #check that the code already never used
  already_used = row[settings.db_codes_indexof_already_used]
  if already_used != 0
    @error = "the code already used"
    return
  end

  #check that the code not expired
  valid_until = row[settings.db_codes_indexof_valid_until]
  now_timestamp = `date +%s`.to_i
  if valid_until <= now_timestamp
    @error = "the code expired"
    return
  end

  #if we are here, then the code is valid and not expired
  session['user'] = row[settings.db_codes_indexof_user]
  session['code'] = row[settings.db_codes_indexof_code]
  session['homepath'] = (`getent passwd #{session['user']}`).split(":")[5]
  session['login'] = true

  #update
  db_execute "
    UPDATE #{settings.db_codes_table_name}
    SET 'already_used' = 1
    WHERE code = '#{code}'"

end

def check_login
  redirect to ('/') if !are_login
end