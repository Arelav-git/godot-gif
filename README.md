LLGif89aDecoder низкоуровневый инструмент,декодирующий все поля файлов формата GIF89a в нативные структуры Godot

установка:
1. скачайте и положите gif89a.gd в любое место в вашем godot проекте
2. готово

сразу начнём с примера воспроизведения gif,добавьте Node2D в сцену и прикрепите следующий скрипт

```
#быстрый старт: воспроизведение гиф с помощью LLGif89aDecoder (godot 4.5.1+)
extends Node2D

#данные фреймов
var gif_delta : PackedFloat64Array = []
var gif_image : Array[ImageTexture] = []
var gif_position : Array[Vector2i] = []
var gif_disposal : PackedByteArray = []
var gif_full_size : Vector2i = Vector2i(2,2)
var gif_background_color : Color = Color(1,1,1,0)

var time : float = 0.0
var full_time : float = 0.0

func _ready() -> void:
	var gif_data : Dictionary[String,Variant] = LLGif89aDecoder.read_gif_from_path("путь к гиф.gif")
	#проверяем,есть ли ошибки
	if gif_data["error"].size() > 0:
		return
	#конвертируем Array[Image] в Array[ImageTexture]
	for image in gif_data["image"]:
		gif_image.push_back(ImageTexture.create_from_image(image))
	
	gif_delta = gif_data["delta"] 
	for delta in gif_delta:
		full_time += delta
	gif_position = gif_data["position"] 
	gif_disposal = gif_data["disposal"] 
	gif_full_size = Vector2i(gif_data["Canvas Width"],gif_data["Canvas Height"] )
	gif_background_color = gif_data["background color"]

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

ниже будут описаны дополнительные возможности LLGif89aDecoder  

аргументы метода read_gif_from_buffer  
buffer : PackedByteArray  
ignore_error : bool = false  
в случае установки true ошибки всё равно будут записываться в ["error"],однако это не оставит чтение gif  
print_unknown_markers : bool = false  
вывод неизвестных маркеров  
print_comment : bool = true  
выводить ли в консоль чьи-то комментарии  
thread_mode : int = 1  
режим распараллеливания декодирования gif  
0 - декодирование выполняется в том же потоке,который вызвал метод  
1 - используется ProjectSettings.threading/worker_pool/low_priority_thread_ratio потоков процессора  
2 - используются все потоки  
используйте режим 2 только если уверены,что делаете  
при большом размере gif режим 2 может вызвать промахи кэша из-за чего итоговое время обработки может оказаться заметно дольше,чем при режиме 1,откалибруйте параметр ProjectSettings.threading/worker_pool/low_priority_thread_ratio что бы у вас выделялось 6-8 потоков если хотите наибыстрейшую скорость декодирования  

ниже буду описаны поля и типы словаря,который возвращают методы read_gif_from_path и read_gif_from_buffer,полное описание полей вы можете прочитать [тут](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp) или [тут](https://www.w3.org/Graphics/GIF/spec-gif89a.txt),тут же будет краткое описание при необходимости  

["error"] : PackedStringArray  
["image"] : Array[Image] - фрейм gif  
["delta"] : PackedFloat64Array - конвертированная дельта  
["position"] : Array[Vector2i]  
["disposal"] : PackedByteArray - метод очистки фрейма  
["background color"] : Color  
["Header"] : String - заголовок,всегда должен быть GIF89a  
["Canvas Width"] : int  
["Canvas Height"] : int  
["Packed Field"] : Dictionary[String,int]  
["Packed Field"]["Global Color Table Flag"] : int  
["Packed Field"]["Color Resolution"] : int  
["Packed Field"]["Sort Flag"] : int  
["Packed Field"]["Size of Global Color Table"] : int  
["Background Color Index"] : int  
["Pixel Aspect Ratio"] : int - необработанное значение  
["Global Color Table"] : PackedColorArray - конвертированные в sRGB цвета  
["Extension Introducer"] : Array  
["Image Descriptor"] : Array  
["Image Data"] : Array  
["Comment Extension"] : PackedStringArray - чьи-то комментарии,никто не знает зачем они нужны  
["Unknown markers"] : PackedInt64Array  

эти поля всегда доступны при условии,что ["error"] пуст  
ниже - поля элементов массивов  

пример обращения к первому полю ["Image Descriptor"]["Image Separator"]["Packed Field"]["Size of Local Color Table"]  
```
func _ready() -> void:
	var gif_data : Dictionary[String,Variant] = LLGif89aDecoder.read_gif_from_path("путь к гиф.gif")
	if gif_data["error"].size() > 0:
		return
	if gif_data["Image Descriptor"].size() > 0:
		print(gif_data["Image Descriptor"][0]["Image Separator"]["Packed Field"]["Size of Local Color Table"])
```

["Extension Introducer"] : Dictionary[String,Variant] - элемент массива ["Extension Introducer"] : Array  

["Extension Introducer"]["Byte Size"] : int  
["Extension Introducer"]["Packed Field"] : Dictionary[String,int]  
["Extension Introducer"]["Delay Time"] : int - не конвертированная дельта  
["Extension Introducer"]["Transparent Color Index"] : int  
["Extension Introducer"]["Packed Field"]["Reserved for Future Use"] : int  
["Extension Introducer"]["Packed Field"]["Disposal Method"] : int - метод очистки фрейма  
["Extension Introducer"]["Packed Field"]["User Input Flag"] : int  
["Extension Introducer"]["Packed Field"]["Transparent Color Flag"] : int  

["Image Descriptor"] : Dictionary[String,Variant] - элемент массива ["Image Descriptor"] : Array  

["Image Descriptor"]["Image Separator"] : Dictionary[String,Variant]  
["Image Descriptor"]["Image Separator"]["Image Left"] : int  
["Image Descriptor"]["Image Separator"]["Image Top"] : int  
["Image Descriptor"]["Image Separator"]["Image Width"] : int  
["Image Descriptor"]["Image Separator"]["Image Height"] : int  
["Image Descriptor"]["Image Separator"]["Local Color Table"] : PackedColorArray - конвертированные в sRGB цвета  
["Image Descriptor"]["Image Separator"]["Packed Field"] : Dictionary[String,int]  
["Image Descriptor"]["Image Separator"]["Packed Field"]["Local Color Table Flag"] : int  
["Image Descriptor"]["Image Separator"]["Packed Field"]["Interlace Flag"] : int  
["Image Descriptor"]["Image Separator"]["Packed Field"]["Sort Flag"] : int  
["Image Descriptor"]["Image Separator"]["Packed Field"]["Reserved For Future Use"] : int  
["Image Descriptor"]["Image Separator"]["Packed Field"]["Size of Local Color Table"] : int  

["Image Descriptor"] ["Image Data"] : Dictionary[String,Variant]  
["Image Descriptor"] ["Image Data"]["LZW Minimum Code Size"] : int  
["Image Descriptor"] ["Image Data"]["Index Stream"] : PackedInt32Array - индексы цветов локального или глобального стола  
["Image Descriptor"] ["Image Data"]["Code streams"] : Array[PackedInt32Array]  
["Image Descriptor"] ["Image Data"]["Tables"] : Array[Dictionary]  
["Image Descriptor"] ["Image Data"]["LZW data"] : PackedByteArray  
["Image Descriptor"] ["Image Data"]["Units"] : int - нигде не используется,просто дебаг информация  

LLGif89aDecoder is a low-level tool that decodes all fields of GIF89a format files into Godot native structures.  

Installation:  
1. Download and place gif89a.gd anywhere in your Godot project.  
2. Done.  

Let's start right away with an example of playing a gif. Add a Node2D to the scene and attach the following script  
```
#Quick start: playing gif with LLGif89aDecoder (godot 4.5.1+)
extends Node2D

#frames data
var gif_delta : PackedFloat64Array = []
var gif_image : Array[ImageTexture] = []
var gif_position : Array[Vector2i] = []
var gif_disposal : PackedByteArray = []
var gif_full_size : Vector2i = Vector2i(2,2)
var gif_background_color : Color = Color(1,1,1,0)

var time : float = 0.0
var full_time : float = 0.0

func _ready() -> void:
	var gif_data : Dictionary[String,Variant] = LLGif89aDecoder.read_gif_from_path("path to gif.gif")
	#check for errors
	if gif_data["error"].size() > 0:
		return
	#conert Array[Image] to Array[ImageTexture]
	for image in gif_data["image"]:
		gif_image.push_back(ImageTexture.create_from_image(image))
	
	gif_delta = gif_data["delta"] 
	for delta in gif_delta:
		full_time += delta
	gif_position = gif_data["position"] 
	gif_disposal = gif_data["disposal"] 
	gif_full_size = Vector2i(gif_data["Canvas Width"],gif_data["Canvas Height"] )
	gif_background_color = gif_data["background color"]

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
The additional features of LLGif89aDecoder will be described below  

arguments of the read_gif_from_buffer method  
buffer : PackedByteArray  
ignore_error: bool = false  
If set to true, errors will still be logged to ["error"], but this will not prevent the GIF from being read.  
print_unknown_markers: bool = false  
Output unknown markers.  
print_comment: bool = true    
Whether to print someone’s comments to the console.  
thread_mode : int = 1  
GIF decoding parallelism mode  
0 - decoding runs in the caller thread  
1 - uses ProjectSettings.threading/worker_pool/low_priority_thread_ratio threads  
2 - uses all available threads  
Use mode 2 only if you know exactly what you are doing.  
For large GIFs, mode 2 can cause cache misses, making total processing time noticeably longer than with mode 1.  
Calibrate ProjectSettings.threading/worker_pool/low_priority_thread_ratio so that 6–8 threads are allocated for fastest decoding.  

Below, the fields and types of the dictionary returned by the methods read_gif_from_path and read_gif_from_buffer are described. You can read the full description of the fields [here](https://www.matthewflickinger.com/lab/whatsinagif/bits_and_bytes.asp) or [here](https://www.w3.org/Graphics/GIF/spec-gif89a.txt),here a brief description will be provided if necessary.  

["error"] : PackedStringArray  
["image"] : Array[Image] - gif frame  
["delta"] : PackedFloat64Array - converted delta  
["position"] : Array[Vector2i]  
["disposal"] : PackedByteArray - frame-clearing method  
["background color"] : Color  
["Header"] : String - header, must always be GIF89a  
["Canvas Width"] : int  
["Canvas Height"] : int  
["Packed Field"] : Dictionary[String,int]  
["Packed Field"]["Global Color Table Flag"] : int  
["Packed Field"]["Color Resolution"] : int  
["Packed Field"]["Sort Flag"] : int  
["Packed Field"]["Size of Global Color Table"] : int  
["Background Color Index"] : int  
["Pixel Aspect Ratio"] : int - raw value  
["Global Color Table"] : PackedColorArray - converted to sRGB colors  
["Extension Introducer"] : Array  
["Image Descriptor"] : Array  
["Image Data"] : Array  
["Comment Extension"] : PackedStringArray - someone’s comments, nobody knows why they’re needed  
["Unknown markers"] : PackedInt64Array  

These fields are always available provided that ["error"] is empty  
Below are the fields of the array elements  

example of accessing the first field ["Image Descriptor"]["Image Separator"]["Packed Field"]["Size of Local Color Table"]  
```
func _ready() -> void:
	var gif_data : Dictionary[String,Variant] = LLGif89aDecoder.read_gif_from_path("путь к гиф.gif")
	if gif_data["error"].size() > 0:
		return
	if gif_data["Image Descriptor"].size() > 0:
		print(gif_data["Image Descriptor"][0]["Image Separator"]["Packed Field"]["Size of Local Color Table"])
```

["Extension Introducer"] : Dictionary[String,Variant] - element of the array ["Extension Introducer"] : Array  

["Extension Introducer"]["Byte Size"] : int  
["Extension Introducer"]["Packed Field"] : Dictionary[String,int]  
["Extension Introducer"]["Delay Time"] : int - non-converted delta  
["Extension Introducer"]["Transparent Color Index"] : int  
["Extension Introducer"]["Packed Field"]["Reserved for Future Use"] : int  
["Extension Introducer"]["Packed Field"]["Disposal Method"] : int - frame-clearing method  
["Extension Introducer"]["Packed Field"]["User Input Flag"] : int  
["Extension Introducer"]["Packed Field"]["Transparent Color Flag"] : int  

["Image Descriptor"] : Dictionary[String,Variant] - element of the array ["Image Descriptor"] : Array  

["Image Descriptor"]["Image Separator"] : Dictionary[String,Variant]  
["Image Descriptor"]["Image Separator"]["Image Left"] : int  
["Image Descriptor"]["Image Separator"]["Image Top"] : int  
["Image Descriptor"]["Image Separator"]["Image Width"] : int  
["Image Descriptor"]["Image Separator"]["Image Height"] : int  
["Image Descriptor"]["Image Separator"]["Local Color Table"] : PackedColorArray - converted to sRGB colors  
["Image Descriptor"]["Image Separator"]["Packed Field"] : Dictionary[String,int]  
["Image Descriptor"]["Image Separator"]["Packed Field"]["Local Color Table Flag"] : int  
["Image Descriptor"]["Image Separator"]["Packed Field"]["Interlace Flag"] : int  
["Image Descriptor"]["Image Separator"]["Packed Field"]["Sort Flag"] : int  
["Image Descriptor"]["Image Separator"]["Packed Field"]["Reserved For Future Use"] : int  
["Image Descriptor"]["Image Separator"]["Packed Field"]["Size of Local Color Table"] : int  

["Image Descriptor"] ["Image Data"] : Dictionary[String,Variant]  
["Image Descriptor"] ["Image Data"]["LZW Minimum Code Size"] : int  
["Image Descriptor"] ["Image Data"]["Index Stream"] : PackedInt32Array - indices into the local or global color table  
["Image Descriptor"] ["Image Data"]["Code streams"] : Array[PackedInt32Array]  
["Image Descriptor"] ["Image Data"]["Tables"] : Array[Dictionary]  
["Image Descriptor"] ["Image Data"]["LZW data"] : PackedByteArray  
["Image Descriptor"] ["Image Data"]["Units"] : int - unused debug information  
