package messenger

import (
	"fmt"
	"io"

	"github.com/pkg/errors"
)

type Messenger interface {
	PrintOut(string)
	PrintErr(string)
}

func write(writer io.Writer, message string) {
	_, err := writer.Write([]byte(message))
	if err != nil {
		err = errors.Wrap(err, fmt.Sprintf("Unable to Write(): '%s'", message))
		panic(err)
	}
}
