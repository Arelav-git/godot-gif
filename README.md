LLGif89aDecoder низкоуровневый инструмент,декодирующий все поля файлов формата GIF89a в нативные структуры Godot

установка:
1. скачайте и положите gif89a.gd в любое место в вашем godot проекте
2. готово

для воспроизведение гиф добавьте к Node2D скрипт со следующим содержанием:  
```gd
extends Node2D

var gif_player : LLGif89aDecoder.GifPlayer = null

func _ready() -> void:
	var data : LLGif89aDecoder.GifData = LLGif89aDecoder.read_gif_from_path("путь к гиф.gif")
	if data.has_error : return
	gif_player = data.Gif_Player
	gif_player.set_canvas_item(self)
```
готово! гиф воспроизведётся при запуске сцены.  

для чтения гиф с буфера замените  
```gd
var data : LLGif89aDecoder.GifData = LLGif89aDecoder.read_gif_from_path("путь к гиф.gif")
```
на 
```gd
var f : FileAccess = FileAccess.open("путь к гиф.gif",FileAccess.READ)
var data : LLGif89aDecoder.GifData = LLGif89aDecoder.read_gif_from_buffer(f.get_buffer(f.get_length()))
```

альтернативный минимальный вариант воспроизведения гиф без использования GifPlayer:  

```gd
#быстрый старт: воспроизведение гиф без использования GifPlayer с помощью LLGif89aDecoder (godot 4.5.1+)
extends Node2D

#данные фреймов
var gif_delta : PackedFloat64Array = []
var gif_image : Array[ImageTexture] = []
var gif_position : PackedVector2Array = []
var gif_disposal : PackedByteArray = []
var gif_full_size : Vector2i = Vector2i(2,2)
var gif_background_color : Color = Color(1,1,1,0)

var time : float = 0.0
var full_time : float = 0.0

func _ready() -> void:
	var data : LLGif89aDecoder.GifData = LLGif89aDecoder.read_gif_from_path("G:/delete/jumping_through_windows.gif")
	if data.has_error : return #проверяем,есть ли ошибки
	gif_delta = data.get_converted_delta()
	gif_image = data.get_image_textures()
	gif_position = data.get_position()
	gif_disposal = data.get_disposal()
	gif_full_size = Vector2i(data.Canvas_Width,data.Canvas_Height)
	gif_background_color = data.background_color
	for i in gif_delta:
		full_time += i

func _process(delta: float) -> void:
	time = wrapf(time + delta,0.0,full_time)
	queue_redraw()

func _draw() -> void:
	var local_time : float = time
	for i in gif_delta.size():
		local_time -= gif_delta[i]
		match gif_disposal[i]:
			2: #очистить до фона
				draw_rect(Rect2i(Vector2.ZERO,gif_full_size),gif_background_color)
			3: #вернуться к предыдущему фрейму
				if local_time < 0.0:
					draw_texture(gif_image[i],gif_position[i])
			_: #0 - метод не требует освобождения,1 - оставить текущее изображение и нарисовать следующее поверх него,4-7 поведение не определено
				draw_texture(gif_image[i],gif_position[i])
		if local_time < 0.0 : break
```

класс GifPlayer - предназначен для простого вопроизведения gif  

методы:  

set_canvas_item(new_canvas_item : $${\color{green}\text{CanvasItem}}$$) - устанавливает CanvasItem на котором будет рисоваться гиф.  
set_speed_scale(new_speed_scale : $${\color{green}\text{float}}$$) - устанавливает множитель скорости воспроизведения гиф,при отрицательном значении гиф будет вопросизводится в обратном порядке.  
set_offset(new_offset : $${\color{green}\text{Vector2}}$$) - устанавливает позицию гиф.  
set_rotation(new_rotation : $${\color{green}\text{float}}$$) - устанавливает поворот гиф в радиантах относильно верхнего левого угла.  
set_rotation_degrees(new_rotation_degress : $${\color{green}\text{float}}$$) - устанавливает поворот гиф в градусах относильно верхнего левого угла.  
set_scale(new_scale : $${\color{green}\text{Vector2}}$$) - устанавливает масштаб гиф.  
set_transform(new_transform : $${\color{green}\text{Transform2D}}$$) - устанавливает Transform2D гиф.  

класс LLGif89aDecoder:  

enum THREAD_MODE {current,auto,low_priority,high_priority}  

THREAD_MODE.current - декодирование выполняется в том же потоке,который вызвал метод  
THREAD_MODE.auto - декодирование выполняется на оптимальном кол-ве потоков (6)  
THREAD_MODE.low_priority - декодирование выполняется с присвоением high_priority = false,по умолчанию будут задействованы 30% потоков (ProjectSettings.threading/worker_pool/low_priority_thread_ratio)  
THREAD_MODE.high_priority - декодирование выполняется с присвоением high_priority = true этот режим будет использовать все потоки,используйте THREAD_MODE.high_priority только если знаете,что делаете,при большом размере gif режим THREAD_MODE.high_priority может вызвать промахи кэша из-за чего итоговое время обработки может оказаться заметно дольше,чем при режиме THREAD_MODE.auto  

аргументы метода read_gif_from_path
path : $${\color{green}\text{String}}$$ - путь к гиф  

аргументы метода read_gif_from_buffer  
buffer : $${\color{green}\text{PackedByteArray}}$$  
generate_gif_player : $${\color{green}\text{bool}}$$ = true - генерировать ли GifPlayer  
_generate_image : $${\color{green}\text{bool}}$$ = true - генерировать ли Image  
thread_mode : LLGif89aDecoder.THREAD_MODE = THREAD_MODE.auto - режим распараллеливания декодирования gif  
print_unknown_markers : $${\color{green}\text{bool}}$$ = false - вывод неизвестных маркеров  
print_comment : $${\color{green}\text{bool}}$$ = true - выводить ли в консоль чьи-то комментарии  


поля которые будут [тут](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp) или [тут](https://www.w3.org/Graphics/GIF/spec-gif89a.txt) будут помечены кликабельными ссылками,тут же будет краткое описание при необходимости  

класс GifData - хранит в себе все поля gif:  

методы:

get_image_textures() -> $${\color{green}\text{Array[ImageTexture]}}$$ - возвращает массив текстур gif  
get_unconverted_delta() -> $${\color{green}\text{PackedInt32Array}}$$ - возвращает массив не конвертированной дельты  
get_converted_delta() -> $${\color{green}\text{PackedFloat64Array}}$$ - возвращает массив конвертированной дельты  
get_disposal() -> $${\color{green}\text{PackedByteArray}}$$ - возвращает массив методов очисти фрейма  
get_position() -> $${\color{green}\text{PackedVector2Array}}$$ - возвращает массив позиции каждой текстуры  

переменные:  

var error :  $${\color{green}\text{PackedStringArray}}$$ = [] - ошибки будут выведены в консоль,однако GifData всё равно будет собирать их  
var has_error :  $${\color{green}\text{bool}}$$ = false  
var unknown_markers :  $${\color{green}\text{PackedInt64Array}}$$ = []  
var graphic_control_label_unknown_markers :  $${\color{green}\text{PackedInt64Array}}$$ = []  
var Graphic_Control_Label   : $${\color{green}\text{Array}}$$[[GraphicControlLabel](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=graphic%20control%20label)]= []  
var Image_Separator :  $${\color{green}\text{Array}}$$[[ImageSeparator](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=byte%20is%20the-,image%20separator,-.%20Every%20image%20descriptor)] = []  
var Image_Data : $${\color{green}\text{Array}}$$[[ImageData](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=RGB%20value%20triplets.-,Image%20Data,follow%20and%20we%20have%20read%20all%20the%20data%20in%20this%20block.,-Plain%20Text%20Extension)] = []  
var [Header](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=Header%20Block,into%20those%20anymore.) :  $${\color{green}\text{String}}$$ = "" - заголовок,всегда должен быть GIF89a  
var [Canvas_Width](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=starts%20with%20the-,canvas%20width,-.%20This%20value%20can) :  $${\color{green}\text{int}}$$ = 0  
var [Canvas_Height](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=might%20expect%2C%20the-,canvas%20height,-follows.%20Again%2C%20in) :  $${\color{green}\text{int}}$$ = 0  
var [Global_Color_Table_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=bit%20is%20the-,global%20color%20table%20flag,-.%20If%20it%27s%200) :  $${\color{green}\text{bool}}$$ = 0  
var [Color_Resolution](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=bits%20represent%20the-,color%20resolution,-.%20The%20spec%20says) :  $${\color{green}\text{int}}$$ = 0  
var [Sort_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=bit%20is%20the-,sort%20flag,-.%20If%20the%20values) :  $${\color{green}\text{bool}}$$ = 0  
var [Size_of_Global_Color_Table](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=size%20of%20global%20color%20table) :  $${\color{green}\text{int}}$$ = 0 - значение после применения формулы 3*2^(N+1)  
var [Background_Color_Index](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=background%20color%20index) :  $${\color{green}\text{int}}$$ = 0  
var [Pixel_Aspect_Ratio](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=descriptor%20is%20the-,pixel%20aspect%20ratio,-.%20I%27m%20not%20exactly) :  $${\color{green}\text{int}}$$ = 0  - необработанное значение  
var [Global_Color_Table](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=all%20N%3C%3E0.-,Global%20Color%20Table,the%20color%20table%20is%20then%20required%20to%20immediately%20follow%20that%20block.,-Graphics%20Control%20Extension) :  $${\color{green}\text{PackedColorArray}}$$ = [] - конвертированные в sRGB цвета  
var [Comment_Extension](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=bytes%20of%20data.-,Comment%20Extension,let%27s%20us%20know%20we%20have%20reached%20the%20end%20of%20the%20block.,-Trailer) :  $${\color{green}\text{PackedStringArray}}$$ = [] - чьи-то комментарии,никто не знает зачем они нужны  

класс [GraphicControlLabel](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=graphic%20control%20label) - элемент массива Graphic_Control_Label в GifData  

var [Byte_Size](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=is%20the%20total-,block%20size,-in%20bytes.%20Next) : $${\color{green}\text{int}}$$ = 0  
var [Delay_Time](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=transparent%20color%20flag-,.%20The%20delay%20time,-value%20follows%20in) : $${\color{green}\text{int}}$$ = 0 - неконвертированная дельта  
var [Transparent_Color_Index](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=transparent%20color%20index) : $${\color{green}\text{int}}$$ = 0  
var [Reserved_for_Future_Use](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=Bits%201%2D3%20are%20reserved%20for%20future%20use.) : $${\color{green}\text{int}}$$ = 0  
var [Disposal_Method](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=4%2D6%20indicate-,disposal%20method,-.%20The%20penult%20bit) : $${\color{green}\text{int}}$$ = 0 - метод очистки фрейма  
var [User_Input_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=bit%20is%20the-,user%20input%20flag,-and%20the%20last) : $${\color{green}\text{bool}}$$ = 0  
var [Transparent_Color_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=transparent%20color%20flag) : $${\color{green}\text{bool}}$$ = 0  

класс [ImageSeparator](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=byte%20is%20the-,image%20separator,-.%20Every%20image%20descriptor) - элемент массива Image_Separator в GifData  

var [Image_Left](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=descriptor%20specifies%20the-,image%20left,-position%20and%20image) : $${\color{green}\text{int}}$$ = 0  
var [Image_Top](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=left%20position%20and-,image%20top,-position%20of%20where) : $${\color{green}\text{int}}$$ = 0  
var [Image_Width](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=it%20specifies%20the-,image%20width,-and%20image%20height) : $${\color{green}\text{int}}$$ = 0  
var [Image_Height](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=image%20width%20and-,image%20height,-.%20Each%20of%20these) : $${\color{green}\text{int}}$$ = 0  
var [Local_Color_Table](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=interlace%20flag.-,Local%20Color%20Table,-The%20local%20color) : $${\color{green}\text{PackedColorArray}}$$ = []  
var [Local_Color_Table_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=byte%20is%20the-,local%20color%20table%20flag,-.%20Setting%20this%20flag) : $${\color{green}\text{bool}}$$ = 0  
var [Interlace_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=bit%20is%20the-,interlace%20flag,-.) : $${\color{green}\text{bool}}$$ = 0  
var [Sort_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=byte%20is%20another-,packed%20field,-.%20In%20our%20sample) : $${\color{green}\text{bool}}$$ = 0  
var [Reserved_For_Future_Use](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=byte%20is%20another-,packed%20field,-.%20In%20our%20sample) : $${\color{green}\text{int}}$$ = 0  
var [Size_of_Local_Color_Table](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=size%20of%20the%20local%20color%20table) : $${\color{green}\text{int}}$$ = 0  

класс [ImageData](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=RGB%20value%20triplets.-,Image%20Data,follow%20and%20we%20have%20read%20all%20the%20data%20in%20this%20block.,-Plain%20Text%20Extension) - элемент массива Image_Data в GifData  

var [LZW_Minimum_Code_Size](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=block%20is%20the-,LZW%20minimum%20code%20size,-.%20This%20value%20is) : $${\color{green}\text{int}}$$ = 0  
var [Index_Stream](https://www.matthewflickinger.com/lab/whatsinagif/lzw_image_data.asp) : $${\color{green}\text{PackedInt32Array}}$$ = []  
var [Code_streams](https://www.matthewflickinger.com/lab/whatsinagif/lzw_image_data.asp) : $${\color{green}\text{Array[PackedInt32Array]}}$$ = []  
var [Tables](https://www.matthewflickinger.com/lab/whatsinagif/lzw_image_data.asp) : $${\color{green}\text{Array[Array]}}$$ = []    
var [Units](https://www.matthewflickinger.com/lab/whatsinagif/lzw_image_data.asp#:~:text=as%20a%20new%20%22-,code%20unit,-%22.%20A%20code%20unit) : $${\color{green}\text{int}}$$ = 0  









LLGif89aDecoder is a low-level tool that decodes all fields of GIF89a format files into Godot native structures.  

Installation:  
1. Download and place gif89a.gd anywhere in your Godot project.  
2. Done.  

To play GIF, add a script to Node2D with the following content:  
```gd
extends Node2D

var gif_player : LLGif89aDecoder.GifPlayer = null

func _ready() -> void:
	var data : LLGif89aDecoder.GifData = LLGif89aDecoder.read_gif_from_path("path to gif.gif")
	if data.has_error : return
	gif_player = data.Gif_Player
	gif_player.set_canvas_item(self)
```
Done! gif will play when the scene starts.  

to read gif from buffer, replace  
```gd
var data : LLGif89aDecoder.GifData = LLGif89aDecoder.read_gif_from_path("path to gif.gif")
```
to  
```gd
var f : FileAccess = FileAccess.open("path to gif.gif",FileAccess.READ)
var data : LLGif89aDecoder.GifData = LLGif89aDecoder.read_gif_from_buffer(f.get_buffer(f.get_length()))
```

alternative minimal version play gif without GifPlayer:  
```gd
#Quick start: playing gif with LLGif89aDecoder (godot 4.5.1+)
extends Node2D

#frames data
var gif_delta : PackedFloat64Array = []
var gif_image : Array[ImageTexture] = []
var gif_position : PackedVector2Array = []
var gif_disposal : PackedByteArray = []
var gif_full_size : Vector2i = Vector2i(2,2)
var gif_background_color : Color = Color(1,1,1,0)

var time : float = 0.0
var full_time : float = 0.0

func _ready() -> void:
	var data : LLGif89aDecoder.GifData = LLGif89aDecoder.read_gif_from_path("G:/delete/jumping_through_windows.gif")
	if data.has_error : return #check for errors
	gif_delta = data.get_converted_delta()
	gif_image = data.get_image_textures()
	gif_position = data.get_position()
	gif_disposal = data.get_disposal()
	gif_full_size = Vector2i(data.Canvas_Width,data.Canvas_Height)
	gif_background_color = data.background_color
	for i in gif_delta:
		full_time += i

func _process(delta: float) -> void:
	time = wrapf(time + delta,0.0,full_time)
	queue_redraw()

func _draw() -> void:
	var local_time : float = time
	for i in gif_delta.size():
		local_time -= gif_delta[i]
		match gif_disposal[i]:
			2: #clear to backgound
				draw_rect(Rect2i(Vector2.ZERO,gif_full_size),gif_background_color)
			3: #restore to previos frame
				if local_time < 0.0:
					draw_texture(gif_image[i],gif_position[i])
			_: #0 - method does not require disposal, 1 - leave the current image and draw the next one on top, 4-7 behavior is undefined
				draw_texture(gif_image[i],gif_position[i])
		if local_time < 0.0 : break
```


Class GifPlayer - designed for simple gif playback.

Methods:  

set_canvas_item(new_canvas_item : $${\color{green}\text{CanvasItem}}$$) -  sets the CanvasItem on which the gif will be drawn.  
set_speed_scale(new_speed_scale : $${\color{green}\text{float}}$$) - sets the playback speed multiplier for the gif,negative value will play the gif in reverse.  
set_offset(new_offset : $${\color{green}\text{Vector2}}$$) - sets the position of the gif.  
set_rotation(new_rotation : $${\color{green}\text{float}}$$) - sets the rotation of the gif in radians relative to the top-left corner.  
set_rotation_degrees(new_rotation_degress : $${\color{green}\text{float}}$$) - sets the rotation of the gif in degrees relative to the top-left corner.  
set_scale(new_scale : $${\color{green}\text{Vector2}}$$) - sets the scale of the gif.  
set_transform(new_transform : $${\color{green}\text{Transform2D}}$$) - sets the Transform2D of the gif.  

Class LLGif89aDecoder:  

enum THREAD_MODE {current,auto,low_priority,high_priority}  

THREAD_MODE.current - decoding is performed in the same thread that called the method.  
THREAD_MODE.auto - decoding is performed using the optimal number of threads (6).  
THREAD_MODE.low_priority - decoding is performed with high_priority = false. By default, 30% of threads will be used (ProjectSettings.threading/worker_pool/low_priority_thread_ratio).  
THREAD_MODE.high_priority - decoding is performed with high_priority = true. This mode will use all threads. Use THREAD_MODE.high_priority only if you know what you are doing. For large GIFs, THREAD_MODE.high_priority may cause cache misses, which can result in significantly longer total processing time compared to THREAD_MODE.auto.  

Arguments for the read_gif_from_path method  
path : $${\color{green}\text{String}}$$ - path to the GIF.  

Arguments for the read_gif_from_buffer method  
buffer : $${\color{green}\text{PackedByteArray}}$$  
generate_gif_player : $${\color{green}\text{bool}}$$ = true 
_generate_image : $${\color{green}\text{bool}}$$ = true
thread_mode : LLGif89aDecoder.THREAD_MODE = THREAD_MODE.auto 
print_unknown_markers : $${\color{green}\text{bool}}$$ = false - output unknown markers.    
print_comment : $${\color{green}\text{bool}}$$ = true - output someone's comments to the console.  


Fields that are described [here](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp) or [here](https://www.w3.org/Graphics/GIF/spec-gif89a.txt) will be marked with clickable links. A brief description will also be provided here if necessary.  

Class GifData - stores all gif fields:  

Methods:

get_image_textures() -> $${\color{green}\text{Array[ImageTexture]}}$$ - returns an array of gif textures  
get_unconverted_delta() -> $${\color{green}\text{PackedInt32Array}}$$ - returns an array of unconverted delta  
get_converted_delta() -> $${\color{green}\text{PackedFloat64Array}}$$ -  returns an array of converted delta  
get_disposal() -> $${\color{green}\text{PackedByteArray}}$$ - returns an array of frame disposal methods  
get_position() -> $${\color{green}\text{PackedVector2Array}}$$ - returns an array of each texture's position  

Variables:  

var error :  $${\color{green}\text{PackedStringArray}}$$ = [] - errors will be printed to the console, but GifData will still collect them  
var has_error :  $${\color{green}\text{bool}}$$ = false  
var unknown_markers :  $${\color{green}\text{PackedInt64Array}}$$ = []  
var graphic_control_label_unknown_markers :  $${\color{green}\text{PackedInt64Array}}$$ = []  
var Graphic_Control_Label   : $${\color{green}\text{Array}}$$[[GraphicControlLabel](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=graphic%20control%20label)]= []  
var Image_Separator :  $${\color{green}\text{Array}}$$[[ImageSeparator](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=byte%20is%20the-,image%20separator,-.%20Every%20image%20descriptor)] = []  
var Image_Data : $${\color{green}\text{Array}}$$[[ImageData](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=RGB%20value%20triplets.-,Image%20Data,follow%20and%20we%20have%20read%20all%20the%20data%20in%20this%20block.,-Plain%20Text%20Extension)] = []  
var [Header](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=Header%20Block,into%20those%20anymore.) :  $${\color{green}\text{String}}$$ = "" - header, must always be GIF89a  
var [Canvas_Width](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=starts%20with%20the-,canvas%20width,-.%20This%20value%20can) :  $${\color{green}\text{int}}$$ = 0  
var [Canvas_Height](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=might%20expect%2C%20the-,canvas%20height,-follows.%20Again%2C%20in) :  $${\color{green}\text{int}}$$ = 0  
var [Global_Color_Table_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=bit%20is%20the-,global%20color%20table%20flag,-.%20If%20it%27s%200) :  $${\color{green}\text{bool}}$$ = 0  
var [Color_Resolution](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=bits%20represent%20the-,color%20resolution,-.%20The%20spec%20says) :  $${\color{green}\text{int}}$$ = 0  
var [Sort_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=bit%20is%20the-,sort%20flag,-.%20If%20the%20values) :  $${\color{green}\text{bool}}$$ = 0  
var [Size_of_Global_Color_Table](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=size%20of%20global%20color%20table) :  $${\color{green}\text{int}}$$ = 0 - value after applying the formula 3*2^(N+1)  
var [Background_Color_Index](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=background%20color%20index) :  $${\color{green}\text{int}}$$ = 0  
var [Pixel_Aspect_Ratio](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=descriptor%20is%20the-,pixel%20aspect%20ratio,-.%20I%27m%20not%20exactly) :  $${\color{green}\text{int}}$$ = 0  - raw value  
var [Global_Color_Table](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=all%20N%3C%3E0.-,Global%20Color%20Table,the%20color%20table%20is%20then%20required%20to%20immediately%20follow%20that%20block.,-Graphics%20Control%20Extension) :  $${\color{green}\text{PackedColorArray}}$$ = [] - colors converted to sRGB  
var [Comment_Extension](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=bytes%20of%20data.-,Comment%20Extension,let%27s%20us%20know%20we%20have%20reached%20the%20end%20of%20the%20block.,-Trailer) :  $${\color{green}\text{PackedStringArray}}$$ = [] - someone's comments, no one knows what they are for  

Class [GraphicControlLabel](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=graphic%20control%20label) - element of the Graphic_Control_Label array in GifData  

var [Byte_Size](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=is%20the%20total-,block%20size,-in%20bytes.%20Next) : $${\color{green}\text{int}}$$ = 0  
var [Delay_Time](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=transparent%20color%20flag-,.%20The%20delay%20time,-value%20follows%20in) : $${\color{green}\text{int}}$$ = 0 - unconverted delta  
var [Transparent_Color_Index](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=transparent%20color%20index) : $${\color{green}\text{int}}$$ = 0  
var [Reserved_for_Future_Use](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=Bits%201%2D3%20are%20reserved%20for%20future%20use.) : $${\color{green}\text{int}}$$ = 0  
var [Disposal_Method](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=4%2D6%20indicate-,disposal%20method,-.%20The%20penult%20bit) : $${\color{green}\text{int}}$$ = 0 - frame disposal method  
var [User_Input_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=bit%20is%20the-,user%20input%20flag,-and%20the%20last) : $${\color{green}\text{bool}}$$ = 0  
var [Transparent_Color_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=transparent%20color%20flag) : $${\color{green}\text{bool}}$$ = 0  

Class [ImageSeparator](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=byte%20is%20the-,image%20separator,-.%20Every%20image%20descriptor) - element of the Image_Separator array in GifData  

var [Image_Left](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=descriptor%20specifies%20the-,image%20left,-position%20and%20image) : $${\color{green}\text{int}}$$ = 0  
var [Image_Top](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=left%20position%20and-,image%20top,-position%20of%20where) : $${\color{green}\text{int}}$$ = 0  
var [Image_Width](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=it%20specifies%20the-,image%20width,-and%20image%20height) : $${\color{green}\text{int}}$$ = 0  
var [Image_Height](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=image%20width%20and-,image%20height,-.%20Each%20of%20these) : $${\color{green}\text{int}}$$ = 0  
var [Local_Color_Table](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=interlace%20flag.-,Local%20Color%20Table,-The%20local%20color) : $${\color{green}\text{PackedColorArray}}$$ = []  
var [Local_Color_Table_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=byte%20is%20the-,local%20color%20table%20flag,-.%20Setting%20this%20flag) : $${\color{green}\text{bool}}$$ = 0  
var [Interlace_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=bit%20is%20the-,interlace%20flag,-.) : $${\color{green}\text{bool}}$$ = 0  
var [Sort_Flag](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=byte%20is%20another-,packed%20field,-.%20In%20our%20sample) : $${\color{green}\text{bool}}$$ = 0  
var [Reserved_For_Future_Use](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=byte%20is%20another-,packed%20field,-.%20In%20our%20sample) : $${\color{green}\text{int}}$$ = 0  
var [Size_of_Local_Color_Table](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=size%20of%20the%20local%20color%20table) : $${\color{green}\text{int}}$$ = 0  

Class [ImageData](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=RGB%20value%20triplets.-,Image%20Data,follow%20and%20we%20have%20read%20all%20the%20data%20in%20this%20block.,-Plain%20Text%20Extension) - element of the Image_Data array in GifData  

var [LZW_Minimum_Code_Size](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp#:~:text=block%20is%20the-,LZW%20minimum%20code%20size,-.%20This%20value%20is) : $${\color{green}\text{int}}$$ = 0  
var [Index_Stream](https://www.matthewflickinger.com/lab/whatsinagif/lzw_image_data.asp) : $${\color{green}\text{PackedInt32Array}}$$ = []  
var [Code_streams](https://www.matthewflickinger.com/lab/whatsinagif/lzw_image_data.asp) : $${\color{green}\text{Array[PackedInt32Array]}}$$ = []  
var [Tables](https://www.matthewflickinger.com/lab/whatsinagif/lzw_image_data.asp) : $${\color{green}\text{Array[Array]}}$$ = []    
var [Units](https://www.matthewflickinger.com/lab/whatsinagif/lzw_image_data.asp#:~:text=as%20a%20new%20%22-,code%20unit,-%22.%20A%20code%20unit) : $${\color{green}\text{int}}$$ = 0  
