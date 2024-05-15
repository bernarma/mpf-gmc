@tool
extends LoggingNode
class_name GMCProcess

var mpf_pid
var is_virtual_mpf := true
var mpf_attempts := 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var args: PackedStringArray = OS.get_cmdline_args()
	if OS.has_feature("spawn_mpf") or "--spawn_mpf" in args or MPF.config.get_value("mpf", "spawn_mpf", false):
		self._spawn_mpf()

func launch_mpf():
	self._spawn_mpf()

func _spawn_mpf():
	self.log.info("Spawning MPF process...")
	var launch_timer = Timer.new()
	launch_timer.connect("timeout", self._check_mpf)
	self.add_child(launch_timer)
	var exec: String = MPF.config.get_value("mpf", "executable_path")
	var args: PackedStringArray = OS.get_cmdline_args()
	var machine_path: String = MPF.config.get_value("mpf", "machine_path",
		ProjectSettings.globalize_path("res://") if OS.has_feature("editor") else OS.get_executable_path().get_base_dir())
	var production_flag := "" # "-P"

	var mpf_args = PackedStringArray([machine_path, "-t"])
	if MPF.config.get_value("mpf", "mpf_args", ""):
		mpf_args.append_array(MPF.config.get_value("mpf", "mpf_args").split())
	if MPF.config.get_value("mpf", "virtual", false):
		mpf_args.append("-x")
	# Doesn't like an empty string, so only include if present
	if production_flag:
		mpf_args.append(production_flag)

	# Generate a timestamped MPF log in the same place as the GMC log
	# mpf_YYYY-MM-DD_HH.mm.ss.log
	var log_path_base = "%s/logs" % OS.get_user_data_dir()
	var dt = Time.get_datetime_dict_from_system()
	var log_file_name = "mpf_%04d-%02d-%02d_%02d.%02d.%02d.log" % [dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second]
	mpf_args.push_back("-l")
	mpf_args.push_back("%s/%s" % [log_path_base, log_file_name])

	if "--v" in args or "--V" in args:
		mpf_args.push_back("-v")
	print("Executing %s" % exec)
	print(mpf_args)
	mpf_pid = OS.create_process(exec, mpf_args, false)
	#var output = []
	#MPF.server.mpf_pid = OS.execute(exec, mpf_args, output, true, true)
	#print(output)
	launch_timer.start(5)

func _check_mpf():
	# Detect if the pid is still alive
	print("Checking MPF PID %s..." % mpf_pid)
	var output = []
	OS.execute("ps", [mpf_pid, "-o", "state="], output, true, true)
	print(output)
	if output and output[0].strip_edges() == "Z":
		mpf_attempts += 1
		if mpf_attempts <= 5:
			print("MPF Failed to Start, Retrying (%s/5)" % mpf_attempts)
			self._spawn_mpf()
		else:
			printerr("ERROR: Unable to start MPF.")

func _exit_tree():
	print("Process exiting tree")
	if mpf_pid:
		print("killing mpf")
		OS.execute("kill", [mpf_pid])
