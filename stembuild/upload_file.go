package main

import (
	"fmt"
	"os"
	"time"

	"github.com/packer-community/winrmcp/winrmcp"
)

func totallyNotMain() { //nolint:unused
	args := os.Args
	err := runMain(args[1], args[2], args[3], args[4], args[5])

	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}
}

func runMain(host string, user string, pass string, source string, destination string) error { //nolint:unused
	client, err := winrmcp.New(host, &winrmcp.Config{
		Auth:                  winrmcp.Auth{User: user, Password: pass},
		Https:                 false,
		Insecure:              true,
		OperationTimeout:      time.Second * 60,
		MaxOperationsPerShell: 15,
	})

	fmt.Print(client)

	if err != nil {
		return err
	}
	return client.Copy(source, destination)
}
