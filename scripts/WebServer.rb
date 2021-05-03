#require 'tempfile'
#require 'sinatra'
#require 'erb'
#require 'sqlite3'
#require 'pathname'
#require 'logger'
#require 'timeout'
#require 'open3'

configure do
  # dont work!(
  # DEBUG < INFO < WARN < ERROR < FATAL < UNKNOWN
  # logger.level = Logger::DEBUG


  enable :sessions
  register Config

  #:root sets implicity
  set :logger, Logger.new(STDOUT)
  set :views, "#{settings.root}/views"
  set :no_auth_neededs, ['/login']
  set :db_codes_columns, Settings.db.table.columns.map { |column| column.name }
  set :bash_default_commands, {}
  Settings.bash.default_commands.each do |elem|
    settings.bash_default_commands[elem.label] = elem.command
  end

  require "#{settings.root}/scripts/ZipGenerator.rb"

  TimeFormat = '%H:%M %d/%m/%y'
end

before do
  redirect to ('/login') unless
    are_login or
    settings.no_auth_neededs.include?(request.path_info)
end

get '/home' do
  erb :index
end

get '/login' do
  code = params['code']
  logger.debug "'get /login' with code '#{code}'"
  login_with_code code
  erb :login
end

get '/fs' do
  session['cur_path'] = session['homepath']
  logger.debug "'get /fs' to homepath '#{session['homepath']}'"
  redirect_to_cur_path
end

get '/fs*' do
  path = params['splat'][0]
  logger.debug "'get /fs*' with path '#{path}'"

  if !File.exist?(path)
    logger.debug "'get /fs*' with path '#{path}' is not exists!" #todo print error message
    redirect_to_cur_path
  end
  if File.file?(path)
    logger.debug "'get /fs*' with path '#{path}' it's file"
    send_file(path, :disposition => 'attachment', :type => 'Application/octet-stream')
    redirect_to_cur_path
  end
  if !File.directory?(path)
    logger.debug "'get /fs*' with path '#{path}' is not directory!"
    puts path + ' is not directory.' #todo print error message
    redirect_to_cur_path
  end

  #correct path
  path = path + '/' if path[-1] != '/'

  #перенаправление если нет прав
  if !system("sudo -u #{session['user']} [ -r #{path} ]") #todo print error message
    logger.debug "'get /fs*' with path '#{path}' permission denied!"
    redirect_to_cur_path
  end
  
  #переменные для шаблона
  @directoryes, @files = parse_dirs_files(path)
  @fullpath_map = get_fullpath_map(path)

  session['cur_path'] = path
  erb :files
end

get '/download' do
  filenames = params['filenames'].split(',')
  logger.debug "'get /download' with filenames: '#{filenames}'"

  if filenames
    download_files(filenames)
  end

  redirect_to_cur_path
end

get '/upload' do
  logger.debug "'get /upload'"
  @default_path = session['cur_path']

  erb :upload
end

post '/upload' do
  logger.debug "'post /upload''"
  upload_file

  redirect_to_cur_path
end

get '/bash' do
  logger.debug "'get /bash''"
  @commands = Settings.bash.default_commands

  erb :bash
end

post '/bash' do
  logger.debug "'post /bash''"
  logger.debug "params: #{params}"

  #get command for execute
  command_label = params["select_command"]
  if command_label == "custom"
    command = params["text_command"]
  else
    command = settings.bash_default_commands[command_label]
  end

  #execute command
  Open3.popen3("sudo -u #{session['user']} #{command}") {|stdin, stdout, stderr, wait_thr|
    #pid = wait_thr.pid
    @status = "Process"

    begin
      Timeout.timeout(Settings.bash.timeout) do
        #logger
        exit_status = wait_thr.value # or maybe Process.wait(pid)
        @status += exit_status.success? ? " ended successfully." : " failed."
      end
    rescue Timeout::Error
      # logger
      Process.kill('TERM', wait_thr.pid) # or maybe Process.kill(9, pid)
      @status += " timed out."
    end

    #where this needed??
    @stdout = stdout.read
    @stderr = stderr.read

  }

  #Timeout.timeout(Settings.bash.timeout) do
  #  @result = %x(sudo -u #{session['user']} #{command} 2>&1)
  #  #@result = `sudo -u #{session['user']} #{command}`
  #  #@result = system("sudo -u #{session['user']} #{command}")
  #  logger.debug @result
  #  puts @result
  #end

  @commands = Settings.bash.default_commands
  erb :bash
end

get '/cat' do
  logger.debug "meow!!!"
  send_file 'cat.jpeg'
end

get '/error' do
  logger.debug "'get /error''"
  halt 401, 'go away!'
end

def redirect_to_cur_path 
  logger.debug "'redirect_to_cur_path' with cur_path '#{session['cur_path']}'"
  redirect to ('/fs' + session['cur_path'])
end

def parse_dirs_files (path)
  logger.debug "'parse_dirs_files' with path '#{path}'"
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
  logger.debug "'get_fullpath_map' with path '#{path}'"
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
  logger.debug "'download_files' with filenames '#{filenames}'"
  dir_path = File.dirname(filenames[0])
  filenames = filenames.map {|filename| File.basename(filename)}

  zip_path = Tempfile.new(['', '.zip'])
  zip_file = ZipFileGenerator.new(dir_path, filenames, zip_path)
  zip_file.write()

  send_file(zip_path, :disposition => 'attachment', :type => 'Application/octet-stream')

  zip_path.unlink()
end

def upload_file
  logger.debug "'upload_file'"
  tempfile = params['file'][:tempfile]
  filename = params['file'][:filename]
  path = params['path']
  FileUtils.copy(tempfile.path, path + filename)
end

def are_login
  session['login']
end

def db_execute comand
  logger.debug "'db_execute' with comand '#{comand}'"
  db = SQLite3::Database.open Settings.db.path
  res = db.execute comand
  db.close if db
  return res
end

def login_with_code code
  logger.debug "'login_with_code' with code '#{code}'"

  #request to db
  row = db_execute "
    SELECT #{settings.db_codes_columns.join(', ')}
    FROM #{Settings.db.table.name}
    WHERE code = '#{code}'"

  #check that code found
  if row == []
    flash[:warning] = "This code not found!"
    return
  end
  row = row[-1] #becase res is array of rows

  #check that the code already never used
  already_used = row[settings.db_codes_columns.index('already_used')]
  if already_used != 0
    flash[:warning] = "This code already used!"
    return
  end

  #check that the code not expired
  valid_until = row[settings.db_codes_columns.index('valid_until')]
  now_timestamp = `date +%s`.to_i
  if valid_until <= now_timestamp
    flash[:warning] = "This code expired!"
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
  
  flash[:success] = "Sign in success."

end

