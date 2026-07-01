# manga-translator
不依赖外部OCR模型的漫画翻译器。  
需要MacOS 14+  
需要Chat Completion API用于翻译（推荐使用Qwen 3-32B，Groq上免费，中文翻译地道）
运行./Scripts/package-app.sh编译。预编译好的.app（仅M系列芯片）在Releases页面下载。

# 使用方法

1. 设置“翻译快捷键”和“移除所选换行快捷键“。后者的作用是移除待翻译内容里的所有换行（一句话被拆分成多行可能影响翻译结果）。推荐设置成同一个，一句话翻译一次。
2. 填入Chat Completion API配置。如原语言不是日文，请自行调整Prompt。

