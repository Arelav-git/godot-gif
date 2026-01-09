@tool
extends Object
class_name LLGif89aDecoder

enum THREAD_MODE {current,auto,low_priority,high_priority}

static func read_gif_from_path(path : String) -> GifData:
	var f : FileAccess = FileAccess.open(path,FileAccess.READ)
	var error : Error = FileAccess.get_open_error()
	if error != Error.OK:
		var gif_data : GifData = GifData.new()
		gif_data.add_error("FileAccess.get_open_error(): %s" % [error])
		return gif_data
	return read_gif_from_buffer(f.get_buffer(f.get_length()))

static func read_gif_from_buffer(buffer : PackedByteArray,
generate_gif_player : bool = true,
_generate_image : bool = true,
thread_mode : THREAD_MODE = THREAD_MODE.auto,
print_unknown_markers : bool = false,
print_comment : bool = true
) -> GifData:
	var data : GifData = GifData.new()
	var reader : ByteReader = ByteReader.new(buffer,data,0)
	data.Header = reader.bytes_to_str(6)
	if data.Header != "GIF89a":
		data.add_error(" wrong gif header,gif header must be GIF89a,current header: %s" % [data.Header])
		return data
	reader.set_and_read(data,["Canvas_Width","Canvas_Height"],[2,2])
	reader.unpack_byte(data,["Global_Color_Table_Flag","Color_Resolution","Sort_Flag","Size_of_Global_Color_Table"],[1,3,1,3])
	reader.set_and_read(data,["Background_Color_Index","Pixel_Aspect_Ratio"],[1,1])
	if data.Global_Color_Table_Flag:
		reader.generate_color_table(data.Global_Color_Table,data.Size_of_Global_Color_Table)
		if data.Global_Color_Table.size() < data.Background_Color_Index:
			data.add_error("Global_Color_Table.size() < data.Background_Color_Index,table size: %s ,index: %s" % [data.Global_Color_Table.size(),data.Background_Color_Index])
			return data
		data.background_color = data.Global_Color_Table[data.Background_Color_Index] 
	reader.byte_offset -= 1
	var tasks : PackedInt64Array = []
	while reader.byte_offset < reader.buffer_size:
		var byte : int = reader.get_byte()
		match byte:
			0x21: #Extension Introducer
				var label : int = reader.get_byte()
				match label:
					0xF9: #Graphic Control Label
						reader.skip_bytes(1)
						var ext : GraphicControlLabel = GraphicControlLabel.new()
						data.Graphic_Control_Label.push_back(ext)
						reader.set_and_read(ext,["Byte_Size"],[1])
						reader.unpack_byte(ext,["Reserved_for_Future_Use","Disposal_Method","User_Input_Flag","Transparent_Color_Flag"],[3,3,1,1])
						reader.set_and_read(ext,["Delay_Time","Transparent_Color_Index"],[2,1])
					0xFE: #Comment Extension
						reader.skip_bytes(1)
						var comment : String = reader.read_str_sub_blocks()
						data.Comment_Extension.push_back(comment)
						if print_comment : print("LLGif89aDecoder found comment: %s" % [comment])
					0x01: #Plain Text Extension 
						reader.skip_bytes(1)
						reader.skip_sub_blocks()
					0xFF: #Application Extension 
						reader.skip_bytes(13)
						reader.skip_sub_blocks()
					_:
						data.graphic_control_label_unknown_markers.push_back(label)
						if print_unknown_markers : push_warning("found unknown marker %s" % [label])
			0x2C: #Image Descriptor
				reader.skip_bytes(1)
				var index : int = data.reserve_index()
				var separator : ImageSeparator = ImageSeparator.new()
				data.Image_Separator.push_back(separator)
				reader.set_and_read(separator,["Image_Left","Image_Top","Image_Width","Image_Height"],[2,2,2,2])
				reader.unpack_byte(separator,["Local_Color_Table_Flag","Interlace_Flag","Sort_Flag","Reserved_For_Future_Use","Size_of_Local_Color_Table"],[1,1,1,2,3])
				if separator.Local_Color_Table_Flag:
					reader.generate_color_table(separator.Local_Color_Table,separator.Size_of_Local_Color_Table)
					if !(data.Graphic_Control_Label.size() > index) : 
						data.add_error("data.Graphic_Control_Label.size(): %s > index: %s" % [data.Graphic_Control_Label.size(),index])
						break 
					if data.Graphic_Control_Label[index].Transparent_Color_Flag:
						if  separator.Local_Color_Table.size() <= data.Graphic_Control_Label[index].Transparent_Color_Index:
							data.add_error("separator.Local_Color_Table.size(): %s <= data.Graphic_Control_Label[index].Transparent_Color_Index: %s" % [separator.Local_Color_Table.size(),data.Graphic_Control_Label[index].Transparent_Color_Index]) 
							break 
						separator.Local_Color_Table[data.Graphic_Control_Label[index].Transparent_Color_Index].a = 0.0
				var binded_mothod : Callable = decode_lzw.bind(ByteReader.new(reader.buffer,data,reader.byte_offset),separator,index,_generate_image)
				match thread_mode:
					THREAD_MODE.current:
						binded_mothod.call()
					THREAD_MODE.low_priority:
						tasks.push_back(WorkerThreadPool.add_task(binded_mothod,false))
					THREAD_MODE.high_priority:
						tasks.push_back(WorkerThreadPool.add_task(binded_mothod,true))
					_:
						if tasks.size() > 5:
							var task_error : Error = WorkerThreadPool.wait_for_task_completion(tasks[0])
							if task_error != Error.OK:
								data.add_error("WorkerThreadPool.wait_for_task_completion error: %s" % [task_error])
							tasks.remove_at(0)
						tasks.push_back(WorkerThreadPool.add_task(binded_mothod,true))
				reader.skip_bytes(1)
				reader.skip_sub_blocks()
	var error : Error = Error.OK
	for task in tasks:
		error = WorkerThreadPool.wait_for_task_completion(task)
		if error != Error.OK:
			data.add_error("WorkerThreadPool.wait_for_task_completion error: %s" % [error])
	if !data.has_error && generate_gif_player:
		data.Gif_Player = GifPlayer.new(data)
	for i in data.Graphic_Control_Label:
		if i.Delay_Time != 0: continue
		i.Delay_Time = 10
	return data

static func decode_lzw(reader : ByteReader,separator : ImageSeparator,index : int,_generate_image : bool) -> void:
	var img : ImageData = ImageData.new()
	reader.set_and_read(img,["LZW_Minimum_Code_Size"],[1])
	var lzw_data : PackedByteArray = reader.get_sub_blocks()
	var lzw_size : int = lzw_data.size()
	var code_clear = 1 << img.LZW_Minimum_Code_Size
	var base_code_size : int = img.LZW_Minimum_Code_Size + 1
	var code_size : int = base_code_size
	var iteration : int = code_clear + 1
	
	var is_inited : bool = false
	var code : int = 0
	var mask : int = 0
	var byte_offset : int = 0
	var bit_offset : int = 0
	var prevcode : int = 0
	var k : int = 0
	var table_size : int = 0
	
	var base_table : Array[PackedInt32Array]= []
	var codestream : PackedInt32Array = []
	var indexstream : PackedInt32Array = []
	var table : Array[PackedInt32Array] = []
	
	base_table.resize(code_clear + 2)
	for i in code_clear:
		base_table[i] = PackedInt32Array([i])
	base_table[code_clear] = PackedInt32Array([])
	base_table[code_clear + 1] = PackedInt32Array([])
	table = base_table.duplicate()
	table_size = table.size()
	while byte_offset < lzw_size:
		#bitreader
		code = 0 
		mask = (1 << code_size) - 1
		for i in (code_size + bit_offset) / 8 + signi((code_size + bit_offset) % 8): 
			if byte_offset + i < lzw_size:
				code |= lzw_data[byte_offset + i] << 8 * i
		code = (code >> bit_offset) & mask
		bit_offset += code_size
		while bit_offset > 7:
			bit_offset -= 8
			byte_offset += 1
		#
		if code == code_clear + 1:
			codestream.push_back(code)
			break
		if code == code_clear:
			code_size = base_code_size
			img.add_to_log(table,codestream,base_table.duplicate())
			is_inited = false
			iteration = code_clear + 1 
			continue
		if !is_inited:
			is_inited = true
			indexstream.append_array(table[code].duplicate())
		else:
			prevcode = codestream[codestream.size() - 1]
			if code <= iteration:
				indexstream.append_array(table[code].duplicate())
				k = table[code][0]
			else:
				k = table[prevcode][0]
				indexstream.append_array(table[prevcode].duplicate())
				indexstream.push_back(k)
			if iteration > 4093:
				continue
			iteration += 1
			if table_size > iteration:
				table[iteration] = table[prevcode].duplicate()
			else:
				table.push_back(table[prevcode].duplicate())
				table_size += 1
			table[iteration].push_back(k)
			if iteration == 2 ** code_size - 1:
				codestream.push_back(code)
				code_size += 1 
				if code_size > 12:
					code_size = base_code_size
					img.add_to_log(table,codestream,base_table.duplicate())
					iteration = code_clear + 1
				continue
		codestream.push_back(code)
	img.Index_Stream = indexstream
	reader.gif_data.override_imagedata_index(img,index)
	if generate_image:
		generate_image(reader.gif_data,separator,img,index)

static func generate_image(data : GifData,separator : ImageSeparator,img : ImageData,index : int) -> void:
	if separator.get_total_pixels() != img.Index_Stream.size():
		data.add_error("gif data corrupted,pixels count != indexstream size,pixels count: %s ,indexstream size: %s " % [separator.get_total_pixels(),img.Index_Stream.size()])
		return
	var color_table : PackedColorArray = []
	color_table = separator.Local_Color_Table if separator.Local_Color_Table_Flag == true else data.Global_Color_Table
	var img_size : Vector2i = separator.get_size()
	var indexstream : PackedInt32Array = img.Index_Stream
	var image : Image = Image.create_empty(img_size.x,img_size.y,false,Image.FORMAT_RGBA8)
	var size_x : int = img_size.x
	for y in img_size.y:
		for x in size_x:
			image.set_pixel(x,y,color_table[indexstream[x + y * size_x]])
	data.override_image_index(image,index)


class ImageData extends RefCounted:
	var LZW_Minimum_Code_Size : int = 0
	var Index_Stream : PackedInt32Array= []
	var Code_streams : Array[PackedInt32Array] = []
	var Tables : Array[Array] = []
	var Units : int = 0
	
	func add_to_log(table : Array[PackedInt32Array],codestream : PackedInt32Array,base_table: Array[PackedInt32Array]) -> void:
		Tables.push_back(table)
		Code_streams.push_back(codestream)
		table = base_table.duplicate()
		codestream = PackedInt32Array([])
		Units += 1

class GraphicControlLabel extends RefCounted:
	var Byte_Size : int = 0
	var Delay_Time : int = 0
	var Transparent_Color_Index : int = 0
	var Reserved_for_Future_Use : int = 0
	var Disposal_Method : int = 0
	var User_Input_Flag : bool = 0
	var Transparent_Color_Flag : bool = 0

class ImageSeparator extends RefCounted:
	var Image_Left : int = 0
	var Image_Top : int = 0
	var Image_Width : int = 0
	var Image_Height : int = 0
	var Local_Color_Table : PackedColorArray = []
	var Local_Color_Table_Flag : bool = 0
	var Interlace_Flag : bool = 0
	var Sort_Flag : bool = 0
	var Reserved_For_Future_Use : int = 0
	var Size_of_Local_Color_Table : int = 0 : set = set_size_table
	
	func set_size_table(new_size : int) -> void:
		Size_of_Local_Color_Table = 3 * 2 ** (new_size + 1)
	
	func get_size() -> Vector2i:
		return Vector2i(Image_Width,Image_Height)
	
	func get_position() -> Vector2i:
		return Vector2i(Image_Left,Image_Top)
	
	func get_total_pixels() -> int:
		return Image_Width * Image_Height

class GifPlayer extends RefCounted:
	var canvas_item : CanvasItem = null : set = set_canvas_item
	
	var time : int = 0
	var full_time : int = 0
	var prev_time : int = 0
	var current_time : int = 0
	var step : int = 0
	
	var speed_scale : float = 1.0
	var offset : Vector2 = Vector2(0,0)
	var rotation : float = 0.0
	var scale : Vector2 = Vector2(1,1)
	
	var background_color : Color = Color(1,1,1,0)
	var full_size : Vector2i = Vector2i(2,2)
	var delta : PackedInt32Array = []
	var image : Array[ImageTexture] = []
	var disposal : PackedByteArray = []
	var position : PackedVector2Array = []
	
	func _draw() -> void:
		var local_time : int = time
		canvas_item.draw_set_transform(offset,rotation,scale)
		for i in delta.size():
			local_time -= delta[i]
			match disposal[i]:
				2: 
					canvas_item.draw_rect(Rect2i(Vector2.ZERO,full_size),background_color)
				3: 
					if local_time < 0.0:
						canvas_item.draw_texture(image[i],position[i])
				_: 
					canvas_item.draw_texture(image[i],position[i])
			if local_time < 0 : break
		canvas_item.draw_set_transform(Vector2(0,0),0.0,Vector2(1,1))
	
	func set_speed_scale(new_speed_scale : float) -> void:
		speed_scale = new_speed_scale
	
	func set_offset(new_offset : Vector2) -> void:
		offset = new_offset
		if canvas_item:
			canvas_item.queue_redraw()
	
	func set_rotation(new_rotation : float) -> void:
		rotation = new_rotation
		if canvas_item:
			canvas_item.queue_redraw()
	
	func set_rotation_degrees(new_rotation_degress : float) -> void:
		rotation = deg_to_rad(new_rotation_degress)
		if canvas_item:
			canvas_item.queue_redraw()
	
	func set_scale(new_scale : Vector2) -> void:
		scale = new_scale
		if canvas_item:
			canvas_item.queue_redraw()
	
	func set_transform(new_transform : Transform2D) -> void:
		offset = new_transform.get_origin()
		rotation = new_transform.get_rotation()
		scale = new_transform.get_scale()
		if canvas_item:
			canvas_item.queue_redraw()
	
	func _init(data : GifData) -> void:
		if !data || data.has_error: return
		full_size = Vector2i(data.Canvas_Width,data.Canvas_Height)
		background_color = data.background_color
		position = data.get_position()
		delta = data.get_unconverted_delta()
		disposal = data.get_disposal()
		for i in delta:
			full_time += i
		for i in data.image:
			image.push_back(ImageTexture.create_from_image(i))
	
	func _process() -> void:
		prev_time = current_time
		current_time = Time.get_ticks_msec() / 10 
		time = wrapi(time + (current_time - prev_time) * speed_scale,0,full_time)
		var local_time : int = time
		var local_step = 0
		for i in delta:
			local_time -= i
			if local_time > 0:
				local_step += 1
				continue
			break
		if local_step != step:
			step = local_step
			canvas_item.queue_redraw()
	
	func set_canvas_item(new_canvas_item : CanvasItem) -> void:
		if canvas_item:
			canvas_item.draw.disconnect(_draw)
			canvas_item.tree_entered.disconnect(canvas_entered_tree)
			canvas_item.tree_exiting.disconnect(canvas_exiting_tree)
			if canvas_item.is_inside_tree() && canvas_item.get_tree().process_frame.is_connected(_process):
				canvas_item.get_tree().process_frame.disconnect(_process)
			canvas_item.queue_redraw()
		canvas_item = new_canvas_item
		if canvas_item :
			canvas_item.draw.connect(_draw)
			canvas_item.tree_entered.connect(canvas_entered_tree)
			canvas_item.tree_exiting.connect(canvas_exiting_tree)
			if canvas_item.is_inside_tree():
				canvas_item.get_tree().process_frame.connect(_process)
			canvas_item.queue_redraw()
	
	func canvas_entered_tree() -> void:
		canvas_item.get_tree().process_frame.connect(_process)
	
	func canvas_exiting_tree() -> void:
		canvas_item.get_tree().process_frame.disconnect(_process)



class GifData extends RefCounted:
	var Gif_Player : GifPlayer = null
	
	var image : Array[Image] = []
	var background_color : Color = Color(1,1,1,0)
	
	var error : PackedStringArray = []
	var has_error : bool = false
	var unknown_markers : PackedInt64Array = []
	var graphic_control_label_unknown_markers : PackedInt64Array = []
	
	var Graphic_Control_Label : Array[GraphicControlLabel] = []
	var Image_Separator : Array[ImageSeparator] = []
	var Image_Data :Array[ImageData] = []
	
	var Header : String = ""
	var Canvas_Width : int = 0
	var Canvas_Height : int = 0
	var Global_Color_Table_Flag : bool = 0
	var Color_Resolution : int = 0
	var Sort_Flag : bool = 0
	var Size_of_Global_Color_Table : int = 0 : set = set_size_table
	var Background_Color_Index : int = 0
	var Pixel_Aspect_Ratio : int = 0
	var Global_Color_Table : PackedColorArray = []
	var Comment_Extension : PackedStringArray = []
	
	var mutex : Mutex = Mutex.new()
	
	func get_image_textures() -> Array[ImageTexture]:
		var array : Array[ImageTexture] = []
		var size : int = image.size()
		array.resize(size)
		for i in size:
			array[i] = ImageTexture.create_from_image(image[i])
		return array
	
	func get_unconverted_delta() -> PackedInt32Array:
		var array : PackedInt32Array = []
		var size : int = Graphic_Control_Label.size()
		array.resize(size)
		for i in size:
			array[i] = Graphic_Control_Label[i].Delay_Time
		return array
	
	func get_converted_delta() -> PackedFloat64Array:
		var array : PackedFloat64Array = []
		var size : int = Graphic_Control_Label.size()
		array.resize(size)
		for i in size:
			array[i] = float(Graphic_Control_Label[i].Delay_Time) / 100.0
		return array
	
	func get_disposal() -> PackedByteArray:
		var array : PackedByteArray = []
		var size : int = Graphic_Control_Label.size()
		array.resize(size)
		for i in size:
			array[i] = Graphic_Control_Label[i].Disposal_Method
		return array
	
	func get_position() -> PackedVector2Array:
		var array : PackedVector2Array = []
		var size : int = Image_Separator.size()
		array.resize(size)
		for i in size:
			array[i] = Vector2(Image_Separator[i].get_position())
		return array
	
	func add_error(text : String) -> void:
		push_error(text)
		mutex.lock()
		error.push_back(text)
		has_error = true
		mutex.unlock()
	
	func reserve_index() -> int:
		mutex.lock()
		var ret_size : int = Image_Data.size() 
		Image_Data.push_back(null)
		image.push_back(null)
		mutex.unlock()
		return ret_size
	
	func override_imagedata_index(img : ImageData,index : int) -> void:
		mutex.lock()
		Image_Data[index] = img
		mutex.unlock()
	
	func override_image_index(img : Image,index : int) -> void:
		mutex.lock()
		image[index] = img
		mutex.unlock()
	
	func set_size_table(new_size : int) -> void:
		Size_of_Global_Color_Table = 3 * 2 ** (new_size + 1)

class ByteReader extends RefCounted:
	var byte_offset : int = 0
	var buffer_size : int = 0
	var buffer : PackedByteArray = []
	var gif_data : GifData = null
	
	func _init(new_buffer : PackedByteArray,new_gif_data : GifData,offset : int) -> void:
		gif_data = new_gif_data
		buffer = new_buffer
		buffer_size = buffer.size() - 1
		byte_offset = offset
	
	func get_byte() -> int:
		if byte_offset + 1 > buffer_size:
			gif_data.add_error("out of buffer,byte offset: %s ,buffer size: %s " % [byte_offset + 1,buffer_size])
			byte_offset += 1
			return 0
		byte_offset += 1
		return buffer[byte_offset]
	
	func skip_bytes(bytes : int) -> void:
		if byte_offset + bytes > buffer_size:
			gif_data.add_error("out of buffer,byte offset: %s ,buffer size: %s " % [byte_offset + bytes,buffer_size])
		byte_offset += bytes
	
	func skip_sub_blocks() -> void:
		while buffer[byte_offset] != 0:
			if gif_data.has_error : return 
			if byte_offset + buffer[byte_offset] + 1 > buffer_size:
				gif_data.add_error("out of buffer,byte offset: %s ,buffer size: %s " % [byte_offset + buffer[byte_offset] + 1,buffer_size])
			byte_offset += buffer[byte_offset] + 1
	
	func get_sub_blocks() -> PackedByteArray:
		var arr_size : int = 0
		var arr : PackedByteArray = []
		while buffer[byte_offset] != 0:
			if gif_data.has_error : break
			if byte_offset + buffer[byte_offset] > buffer_size:
				gif_data.add_error("out of buffer,byte offset: %s ,buffer size: %s " % [byte_offset + buffer[byte_offset] + 1,buffer_size])
				break
			arr.resize(arr_size + buffer[byte_offset] )
			for i in buffer[byte_offset]:
				arr[arr_size + i] = buffer[byte_offset + i + 1]
			arr_size += buffer[byte_offset] 
			byte_offset += buffer[byte_offset] + 1
		return arr
	
	func read_str_sub_blocks() -> String:
		var _str : String = ""
		while buffer[byte_offset] != 0:
			if gif_data.error.size() != 0 : return _str
			if byte_offset + buffer[byte_offset] > buffer_size:
				gif_data.add_error("out of buffer,byte offset: %s ,buffer size: %s " % [byte_offset + buffer[byte_offset],buffer_size])
			for i in buffer[byte_offset]:
				_str += char(buffer[byte_offset + i + 1])
			byte_offset += buffer[byte_offset] + 1
		return _str
	
	func generate_color_table(table : PackedColorArray,color_bytes : int) -> void:
		if byte_offset + color_bytes > buffer_size:
			gif_data.add_error("out of buffer,byte offset: %s ,buffer size: %s " % [byte_offset + color_bytes,buffer_size])
			byte_offset += color_bytes
			return
		for i in range(byte_offset,byte_offset + color_bytes,3):
			table.push_back(Color.from_rgba8(buffer[i],buffer[i + 1],buffer[i + 2]))
		byte_offset += color_bytes
	
	func set_and_read(ref : RefCounted,set_buffer : PackedStringArray,set_bytes : PackedByteArray) -> void:
		var value : int = 0
		for i in set_buffer.size():
			if byte_offset + i > buffer_size:
				gif_data.add_error("out of buffer,byte offset: %s ,buffer size: %s " % [byte_offset + i,buffer_size])
				byte_offset += i
				return
			value = 0
			for j in set_bytes[i]:
				value |= int(buffer[byte_offset + j]) << (8 * j)
			byte_offset += set_bytes[i]
			ref.set(set_buffer[i],value)
	
	func unpack_byte(ref : RefCounted,set_buffer : PackedStringArray,set_bites : PackedByteArray) -> void:
		if byte_offset + 1  > buffer_size:
			gif_data.add_error("out of buffer,byte offset: %s ,buffer size: %s " % [byte_offset + 1,buffer_size])
			byte_offset += 1
			return
		var byte : int = buffer[byte_offset]
		byte_offset += 1
		var bit_offset : int = 0
		var value : int = 0
		var element : int = set_buffer.size() - 1
		while element >= 0:
			value = (byte >> bit_offset) & ((1 << set_bites[element]) - 1)
			ref.set(set_buffer[element],value)
			bit_offset += set_bites[element]
			element -= 1
			
	
	func bytes_to_str(bytes : int ) -> String:
		var _str : String = ""
		if byte_offset + bytes > buffer_size:
			gif_data.add_error("out of buffer,byte offset: %s ,buffer size: %s " % [byte_offset + bytes,buffer_size])
		else :
			for i in bytes:
				_str += char(buffer[byte_offset + i])
		byte_offset += bytes
		return _str
