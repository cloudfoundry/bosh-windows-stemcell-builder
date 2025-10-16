package colorlogger

import (
	"fmt"
	"io"
	"log"
)

const (
	NONE  = -1
	DEBUG = 0

	debug             = "debug"
	plainPrefixFormat = "%s:"
	colorPrefixFormat = "\033[32m%s:\033[0m"
)

type colorLogger struct {
	color    bool
	logger   *log.Logger
	logLevel int
}

type Logger interface {
	Printf(format string, args ...interface{})
}

func New(logLevel int, color bool, writer io.Writer) Logger {
	return &colorLogger{
		color:    color,
		logger:   log.New(writer, "", 0),
		logLevel: logLevel,
	}
}

func (cl *colorLogger) Printf(format string, a ...interface{}) {
	if cl.logLevel >= DEBUG && cl.logLevel != NONE {
		cl.logger.Printf("%s %s", cl.prefix(), fmt.Sprintf(format, a...))
	}
}

func (cl *colorLogger) prefix() string {
	prefixFormat := plainPrefixFormat
	if cl.color {
		prefixFormat = colorPrefixFormat
	}

	return fmt.Sprintf(prefixFormat, debug)
}
