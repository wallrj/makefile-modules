package main

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var CommandRoot = cobra.Command{
	Use: "image-tool",
}

func main() {
	CommandRoot.AddCommand(&CommandAppendLayers)
	CommandRoot.AddCommand(&CommandConvertToDockerTar)
	CommandRoot.AddCommand(&CommandListDigests)
	must("error running command", CommandRoot.Execute())
}

func must(msg string, err error) {
	if err != nil {
		fail(msg+": %w", err)
	}
}

func fail(msg string, a ...any) {
	fmt.Fprintf(os.Stderr, msg+"\n", a...)
	os.Exit(1)
}
