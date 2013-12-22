package main

//#include <gdk/gdk.h>
import "C"

import (
	"bytes"
	"encoding/xml"
	"fmt"
	"io/ioutil"
	"log"
	"math/rand"
	"os"
	"os/user"
	"path/filepath"
	"regexp"
	"runtime"
	"time"
	"unicode/utf8"
	"unsafe"
)

func init() {
	runtime.GOMAXPROCS(32)
	rand.Seed(time.Now().UnixNano())
	fmt.Printf("")
}

func main() {
	lua, err := NewLua(filepath.Join(filepath.Dir(os.Args[0]), "main.lua"))
	if err != nil {
		log.Fatal(err)
	}

	lua.RegisterFunctions(map[string]interface{}{
		// test
		"foobar": func() {
			go func() {
				for i := 0; i < 10; i++ {
					time.Sleep(time.Millisecond * 200)
					lua.Results <- &Result{"foobar", "FOOBAR"}
				}
			}()
		},

		// argv
		"argv": func() []string {
			return os.Args[1:]
		},

		// path utils
		"program_path": func() string {
			abs, _ := filepath.Abs(os.Args[0])
			return filepath.Dir(abs)
		},
		"abspath": func(p string) string {
			abs, _ := filepath.Abs(p)
			return abs
		},
		"dirname": func(p string) string {
			return filepath.Dir(p)
		},
		"basename": func(p string) string {
		  return filepath.Base(p)
		},
		"splitpath": func(p string) (string, string) {
			return filepath.Split(p)
		},
		"joinpath": func(ps ...string) string {
			res := ""
			for _, part := range ps {
				res = filepath.Join(res, part)
			}
			return res
		},
		"pathsep": func() string {
			return string(os.PathSeparator)
		},
		"homedir": func() string {
			user, err := user.Current()
			if err != nil {
				return ""
			}
			return user.HomeDir
		},
		"fileexists": func(p string) bool {
			_, err := os.Stat(p)
			return err == nil
		},
		"mkdir": func(p string) bool {
			return os.Mkdir(p, 0755) != nil
		},

		// time
		"current_time_in_millisecond": func() int64 {
			t := time.Now().UnixNano() / 1000000
			return t
		},

		// file utils
		"listdir": func(path string) ([]string, bool) {
			files, err := ioutil.ReadDir(path)
			if err != nil {
				return nil, true
			}
			var names []string
			for _, info := range files {
				names = append(names, info.Name())
			}
			return names, false
		},
		"isdir": func(path string) bool {
			info, err := os.Stat(path)
			if err != nil {
				return false
			}
			return info.IsDir()
		},
		"filemode": func(path string) os.FileMode {
			info, err := os.Stat(path)
			if err != nil {
				return 0
			}
			return info.Mode()
		},
		"createwithmode": func(path string, mode uint32) bool {
			f, err := os.OpenFile(path, os.O_WRONLY|os.O_CREATE, os.FileMode(mode))
			if err != nil {
				return true
			}
			f.Close()
			return false
		},
		"movefile": func(src, dst string) bool {
			info, err := os.Stat(src)
			if err != nil {
				return true
			}
			mode := info.Mode()
			_, err = os.Stat(dst)
			if err == nil { // dst exists
				return true
			}
			f, err := os.OpenFile(dst, os.O_WRONLY|os.O_CREATE, mode)
			if err != nil {
				return true
			}
			defer f.Close()
			content, err := ioutil.ReadFile(src)
			if err != nil {
				return true
			}
			f.Write(content)
			return false
		},
		"rename": func(src, dst string) bool {
			return os.Rename(src, dst) != nil
		},

		// text utils
		"escapemarkup": func(s string) string {
			buf := new(bytes.Buffer)
			err := xml.EscapeText(buf, []byte(s))
			if err != nil {
				return ""
			}
			return string(buf.Bytes())
		},
		"tochar": func(r rune) string {
			return string(r)
		},
		"regexindex": func(pattern, content string) interface{} {
			re, err := regexp.Compile(pattern)
			if err != nil {
				return false
			}
			indexes := re.FindAllStringSubmatchIndex(content, -1)
			if indexes == nil {
				return false
			}
			return indexes
		},
		"regexfindall": func(pattern, content string) (ret []string) {
			re := regexp.MustCompile(pattern)
			if words := re.FindAllString(content, -1); words != nil {
				ret = words
			}
			return
		},
		"is_valid_utf8": func(input []byte) bool {
			return utf8.Valid(input)
		},

		// gdk
		"gdk_event_copy": func(event unsafe.Pointer) *C.GdkEvent {
			return C.gdk_event_copy((*C.GdkEvent)(event))
		},
		"gdk_event_put": func(event unsafe.Pointer) {
			C.gdk_event_put((*C.GdkEvent)(event))
		},
	})

	lua.Run()
}
