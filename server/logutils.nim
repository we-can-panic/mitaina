# import logging

type
  LogDestination* = enum
    ldFile
    ldConsole

  MyLogger = object
    dst*: LogDestination = ldConsole
    file*: string = "log.txt"

var
  internalLogger * {.threadvar.}: MyLogger

proc setLogger * () =
  internalLogger = MyLogger()

proc log * (text: varargs[string, `$`]) {.gcsafe.}=
  case internalLogger.dst:
  of ldFile:
    let f = open(internalLogger.file, fmAppend)
    f.write(text)
  of ldConsole:
    echo text
