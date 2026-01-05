@tool
extends Object
class_name LLGif89aDecoder

static func read_gif_from_buffer(buffer : PackedByteArray,
ignore_error : bool = false,
print_unknown_markers : bool = false,
print_comment : bool = true,
thread_mode : int = 1) -> Dictionary[String,Variant]:
	
	var buffer_size : int = buffer.size() - 1
	var error : PackedStringArray = PackedStringArray()
	var image : Array[Image] = []
	var delta : PackedFloat64Array = PackedFloat64Array()
	var position : Array[Vector2i] = []
	var disposal : PackedByteArray = PackedByteArray()
	
	var data : Dictionary[String,Variant] = {}
	data["error"] = error
	data["image"] = image
	data["delta"] = delta
	data["position"] = position
	data["disposal"] = disposal
	data["background color"] = Color(1,1,1,0)
	
	var tasks : Array[int] = []
	
	if condition_check(func () -> bool : return buffer_size < 35,
	" buffer.size() < 35 ,file size: %s" % [buffer_size],error,ignore_error):
		return data
	
	var header_check : String = ""
	for i in 6:
		header_check += char(buffer[i])
	
	if condition_check( func() -> bool : return header_check != "GIF89a",
	" wrong gif header,gif header must be GIF89a,current header: %s" % [header_check],error,ignore_error):
		return data
	
	var global_table_colors : PackedColorArray = []
	var global_packed_field : Dictionary[String,int] = {}
	data["Header"] = header_check
	data["Canvas Width"] = buffer[6] + (int(buffer[7]) << 8)
	data["Canvas Height"] = buffer[8] + (int(buffer[9]) << 8)
	global_packed_field["Global Color Table Flag"] = buffer[10] >> 7 & 1
	global_packed_field["Color Resolution"] = buffer[10] >> 4 & 0b111
	global_packed_field["Sort Flag"] = buffer[10] >> 3 & 1
	var global_table_size : int = 3 * 2**(int(buffer[10] & 0b111) + 1)
	global_packed_field["Size of Global Color Table"] = global_table_size
	data["Packed Field"] = global_packed_field
	data["Background Color Index"] = buffer[11]
	data["Pixel Aspect Ratio"] = buffer[12]
	data["Global Color Table"] = global_table_colors
	var byte_offset : int = 12
	
	if global_packed_field["Global Color Table Flag"] == 1:
		byte_offset += global_table_size
		for i in range(13,13 + global_table_size,3):
			global_table_colors.push_back(Color.from_rgba8(buffer[i],buffer[i + 1],buffer[i + 2]))
		data["background color"] = global_table_colors[data["Background Color Index"]]
	data["Extension Introducer"] = Array()
	data["Image Descriptor"] = Array()
	
	data["Comment Extension"] = PackedStringArray([])
	data["Unknown markers"] = PackedInt64Array([])
	data["async error"] = PackedStringArray([])
	var mutex : Mutex = Mutex.new()
	while byte_offset < buffer_size:
		byte_offset += 1 
		match buffer[byte_offset]:
			0x21: #Extension Introducer
				var label : int = buffer[byte_offset + 1]
				match label:
					0xF9: #Graphic Control Label
						var field_byte : int = buffer[byte_offset + 3]
						var packed_field : Dictionary[String,int] = {}
						var extesion_introducer : Dictionary[String,Variant] = {}
						data["Extension Introducer"].push_back(extesion_introducer)
						extesion_introducer["Byte Size"] = buffer[byte_offset + 2]
						extesion_introducer["Packed Field"] = packed_field
						extesion_introducer["Delay Time"] = buffer[byte_offset + 4] + (int(buffer[byte_offset + 5]) << 8)
						if extesion_introducer["Delay Time"] == 0:
							extesion_introducer["Delay Time"] = 10
						extesion_introducer["Transparent Color Index"] = buffer[byte_offset + 6] 
						packed_field["Reserved for Future Use"] = field_byte >> 5
						packed_field["Disposal Method"] = field_byte >> 2 & 0b111
						packed_field["User Input Flag"] = field_byte >> 1 & 1
						packed_field["Transparent Color Flag"] = field_byte & 1
						disposal.push_back(field_byte >> 2 & 0b111)
						delta.push_back(float(extesion_introducer["Delay Time"]) / 100.0)
						if condition_check(func() -> bool : return buffer[byte_offset + 7] != 0,
						" Block Terminator not 0,current Block Terminator: %s" % [buffer[byte_offset + 7]],
						error,ignore_error,byte_offset,tasks ) : 
							return data
						byte_offset += 7 
					0xFE: #Comment Extension
						var comment : String = ""
						byte_offset += 2
						while buffer[byte_offset] != 0 :
							for i in buffer[byte_offset]:
								comment += char(buffer[byte_offset + 1 + i])
							byte_offset += buffer[byte_offset] + 1
						data["Comment Extension"].push_back(comment)
						if print_comment : print("LLGif89aDecoder found comment: %s" % [comment]) 
					0x01: #Plain Text Extension 
						byte_offset += 2
						while buffer[byte_offset] != 0 :
							byte_offset += buffer[byte_offset] + 1
					0xFF: # Application Extension 
						byte_offset += 14
						while buffer[byte_offset] != 0: 
							byte_offset += buffer[byte_offset] + 1
			0x2C: #Image Descriptor
				var image_descriptor : Dictionary[String,Variant] = {}
				var image_separator : Dictionary[String,Variant] = {}
				mutex.lock()
				var push_index : int = data["Image Descriptor"].size()
				data["Image Descriptor"].push_back(null)
				data["image"].push_back(null)
				mutex.unlock()
				image_descriptor["Image Separator"] = image_separator
				var local_table_colors : PackedColorArray = []
				image_separator["Image Left"] = buffer[byte_offset + 1] + (int(buffer[byte_offset + 2]) << 8)
				image_separator["Image Top"] = buffer[byte_offset + 3] + (int(buffer[byte_offset + 4]) << 8)
				image_separator["Image Width"] = buffer[byte_offset + 5] + (int(buffer[byte_offset + 6]) << 8)
				image_separator["Image Height"] = buffer[byte_offset + 7] + (int(buffer[byte_offset + 8]) << 8)
				image_separator["Local Color Table"] = local_table_colors
				position.push_back(Vector2i(image_separator["Image Left"],image_separator["Image Top"]))
				var packed_field : Dictionary[String,int] = {}
				var field_byte : int = buffer[byte_offset + 9]
				image_separator["Packed Field"] = packed_field
				packed_field["Local Color Table Flag"] = field_byte >> 7
				packed_field["Interlace Flag"] = field_byte >> 6 & 1
				packed_field["Sort Flag"] = field_byte >> 5 & 1
				packed_field["Reserved For Future Use"] = field_byte >> 3 & 0b11
				packed_field["Size of Local Color Table"] = 3 * 2**(int(field_byte & 0b111) + 1)
				byte_offset += 10 
				if packed_field["Local Color Table Flag"] == 1:
					for i in range(byte_offset,byte_offset + packed_field["Size of Local Color Table"],3):
						local_table_colors.push_back(Color.from_rgba8(buffer[i],buffer[i + 1],buffer[i + 2]))
				if data["Extension Introducer"][push_index]["Packed Field"]["Transparent Color Flag"] == 1:
					var transparent_index : int = data["Extension Introducer"][push_index]["Transparent Color Index"]
					if local_table_colors.size() > transparent_index:
						local_table_colors[transparent_index] = Color(1,1,1,0)
				if packed_field["Local Color Table Flag"] == 1:
					byte_offset += packed_field["Size of Local Color Table"] 
				var image_data : Dictionary[String,Variant] = {}
				image_descriptor["Image Data"] = image_data
				image_data["LZW Minimum Code Size"] = buffer[byte_offset] 
				byte_offset += 1 
				var base_sub_block_data : int = buffer[byte_offset] 
				var sub_block_data : int =  base_sub_block_data
				var lzw_data : PackedByteArray = []
				while sub_block_data != 0:
					for i in sub_block_data :
						lzw_data.push_back(buffer[byte_offset + 1 + i])
					byte_offset += sub_block_data + 1
					sub_block_data = buffer[byte_offset]
				var binded_method : Callable = decode_lzw.bind(lzw_data,
					image_data,data,mutex,image_descriptor,push_index,ignore_error)
				match thread_mode:
					1:
						tasks.push_back(WorkerThreadPool.add_task(binded_method,false))
					2:
						tasks.push_back(WorkerThreadPool.add_task(binded_method,true))
					_:
						binded_method.call()
			0x3B:
				wait_tasks(tasks,error)
				for async_error in data["async error"]:
					push_error(async_error)
					error.push_back(async_error)
				
				return data
			_:
				data["Unknown markers"].push_back(buffer[byte_offset])
				if print_unknown_markers : 
					push_warning("found unknown marker %s" % [buffer[byte_offset]])
	wait_tasks(tasks,error)
	for async_error in data["async error"]:
		push_error(async_error)
		error.push_back(async_error)
	return data

static func decode_lzw(lzw_data : PackedByteArray,
image_data : Dictionary[String,Variant],
data : Dictionary[String,Variant],
mutex : Mutex,
image_descriptor : Dictionary[String,Variant],
push_pos : int,
ignore_error : bool
) -> void:
	
	var code_clear : int = 1 << image_data["LZW Minimum Code Size"]
	var base_table : Dictionary[int,PackedInt32Array] = {}
	for i in code_clear:
		base_table[i] = PackedInt32Array([i])
	base_table[code_clear + 0] = PackedInt32Array([])
	base_table[code_clear + 1] = PackedInt32Array([])
	var table : Dictionary[int,PackedInt32Array] = base_table.duplicate()
	var iterations : int = code_clear + 1 
	var base_code_size : int =  image_data["LZW Minimum Code Size"] + 1 
	var code_size : int = base_code_size
	
	var codestream : PackedInt32Array = []
	var indexstream : PackedInt32Array = []
	
	var byteoffset : int = 0
	var bitoffset : int = 0
	var bits_get : int = 0
	var go_left : int = 0
	var units_size : int = 0 #add to log
	var code : int = 0
	var prevcode : int = 0
	var k : int = 0
	
	var lzw_size : int = lzw_data.size()
	
	var tables : Array[Dictionary] = []
	var code_streams : Array[PackedInt32Array] = []
	image_data["Index Stream"] = indexstream
	image_data["Code streams"] = code_streams
	image_data["Tables"] = tables
	image_data["LZW data"] = lzw_data
	
	while byteoffset < lzw_size:
		#bitreader start
		code = 0 
		bits_get = code_size
		go_left = 0
		while bits_get > 0:
			if byteoffset < lzw_size:
				code |= ((lzw_data[byteoffset] >> bitoffset) & 1) << go_left 
			else :
				break
			bitoffset += 1
			go_left += 1
			bits_get -= 1
			while bitoffset > 7:
				bitoffset -= 8
				byteoffset += 1
		#bitreader end
		if code == code_clear + 1:
			codestream.push_back(code)
			break
		if code == code_clear:
			code_size = base_code_size
			tables.push_back(table.duplicate())
			code_streams.push_back(codestream.duplicate())
			table = base_table.duplicate()
			codestream.clear()
			units_size += 1
			iterations = code_clear + 1 
			continue
		if codestream.size() == 0:
			indexstream.append_array(table[code].duplicate())
		else:
			prevcode = codestream[codestream.size() - 1]
			if code <= iterations:
				indexstream.append_array(table[code].duplicate())
				k = table[code][0]
			else:
				k = table[prevcode][0]
				indexstream.append_array(table[prevcode].duplicate())
				indexstream.push_back(k)
			if units_size > 0 && indexstream.size() == 1:
				indexstream.remove_at(0)
			if iterations < 4094 :
				iterations += 1
				table[iterations] = table[prevcode].duplicate()
				table[iterations].push_back(k)
				if iterations == 2 ** code_size - 1:
					codestream.push_back(code)
					code_size += 1 
					if code_size > 12:
						code_size = base_code_size
						tables.push_back(table.duplicate())
						code_streams.push_back(codestream.duplicate())
						table = base_table.duplicate()
						codestream.clear()
						iterations = code_clear + 1
					continue
			else :
				continue
		codestream.push_back(code)
	
	image_data["Units"] = units_size
	var image_separator : Dictionary[String,Variant] = image_descriptor["Image Separator"]
	var for_check_x : int = image_separator["Image Width"]
	var for_check_y : int = image_separator["Image Height"]
	var check : int = for_check_x * for_check_y
	
	if check != indexstream.size():
		mutex.lock()
		data["async error"].push_back("async error,gif data corrupted,pixels count != indexstream size,push_pos: %s ,last lzw byte: %s ,pixels count: %s ,indexstream size: %s " % [push_pos,byteoffset,check,indexstream.size()])
		mutex.unlock()
		if !ignore_error : return
	else: #generate image
		var image : Image = Image.create_empty(for_check_x,for_check_y,false,Image.FORMAT_RGBA8)
		var x : int = 0
		var y : int = 0
		var color_table : PackedColorArray = []
		if image_separator["Packed Field"]["Local Color Table Flag"] == 1:
			color_table = image_separator["Local Color Table"]
		else:
			color_table = data["Global Color Table"]
		var table_size : int = color_table.size()
		if push_pos == 0 && table_size > data["Background Color Index"]:
			image.fill(color_table[data["Background Color Index"]])
		for i in indexstream:
			image.set_pixel(x,y,color_table[i])
			x += 1
			if x >= for_check_x:
				x = 0
				y += 1
		mutex.lock()
		data["image"][push_pos] = image
		mutex.unlock()
	mutex.lock()
	data["Image Descriptor"][push_pos] = image_descriptor
	mutex.unlock()

static func read_gif_from_path(path : String) -> Dictionary[String,Variant]:
	var f : FileAccess = FileAccess.open(path,FileAccess.READ)
	var error : Error = FileAccess.get_open_error()
	var dict_errors : PackedStringArray = PackedStringArray()
	var dict : Dictionary[String,Variant] = {}
	dict["error"] = dict_errors
	if condition_check(func () -> bool : return error != OK,
	"FileAccess.get_open_error(): %s" % [error],dict_errors) : 
		return dict
	return read_gif_from_buffer(f.get_buffer(f.get_length()))

static func condition_check(
condition : Callable = func() -> bool : return false,
error_text : String = "",
errors : PackedStringArray = PackedStringArray(),
ignore_error : bool = false,
error_byte : int = 0,
tasks : Array[int] = []) -> bool:
	var error : bool = condition.call()
	if error:
		errors.push_back("error on byte: %s error text: %s" % [error_byte,error_text])
		push_error(error_text)
	var error_value : bool = error if ignore_error == false else false 
	if error_value:
		wait_tasks(tasks,errors)
	return error_value

static func wait_tasks(tasks : Array[int],errors : PackedStringArray) -> void :
	var error : Error = Error.OK
	for i in tasks:
		error = WorkerThreadPool.wait_for_task_completion(i)
		if error != Error.OK :
			push_error("WorkerThreadPool.wait_for_task_completion error: %s" % [error])
			errors.push_back("WorkerThreadPool.wait_for_task_completion error: %s" % [error])
	tasks.clear()
