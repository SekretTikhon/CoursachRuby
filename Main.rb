require "tempfile"
require "sinatra"
require "erb"
require "./ZipGenerator"

enable :sessions
set :root, './'
set :views, './views'

cur_path = nil
#listfiles = nil
#home_path = '/home/tikhon/'
TimeFormat = "%H:%M %d/%m/%y"
info = nil

configure do
  set :no_auth_neededs, ['/login']
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
  key = params["key"]
  login_with_key key

  erb :login
end

get '/error' do
  halt 401, 'go away!'
end

get '/fs' do
  cur_path = session['homepath'] #home_path
  redirect to ('/fs' + cur_path)
end

get '/fs*' do
  param = params['splat'][0]

  #puts '--------------------------'
  #puts "path:      \t" + param
  #puts "Exist:     \t" + File.exist?(param).to_s
  #puts "file?:     \t" + File.file?(param).to_s
  #puts "directory?:\t" + File.directory?(param).to_s

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

    # $?.exitstatus || popen

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

def login_with_key key
  if key == 'key' # проверка ключа
    session['key'] = key
    session['login'] = true
    session['user'] = 'sekret-tikhon'
    session['homepath'] = '/home/' + session['user'] + '/'
  elsif key == 'user1key'
    session['key'] = key
    session['login'] = true
    session['user'] = 'user1'
    session['homepath'] = '/home/' + session['user'] + '/'
  end
end

def check_login
  redirect to ('/login') if !are_login
end
