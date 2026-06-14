package config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sync"
)

type ConfigFile struct {
	Course     [][]string `json:"course"`
	DelCourses [][]string `json:"delcourses"`
}

var (
	cfg     ConfigFile
	cfgPath string
	mu      sync.RWMutex
)

func init() {
	exe, _ := os.Executable()
	cfgPath = filepath.Join(filepath.Dir(exe), "config.json")
	Load()
}

func Path() string { return cfgPath }

func Load() {
	mu.Lock()
	defer mu.Unlock()

	data, err := os.ReadFile(cfgPath)
	if err != nil {
		cfg = ConfigFile{Course: [][]string{}, DelCourses: [][]string{}}
		return
	}
	if err := json.Unmarshal(data, &cfg); err != nil {
		cfg = ConfigFile{Course: [][]string{}, DelCourses: [][]string{}}
	}
}

func Save() {
	mu.RLock()
	data, err := json.MarshalIndent(cfg, "", "  ")
	mu.RUnlock()
	if err != nil {
		return
	}
	os.WriteFile(cfgPath, data, 0644)
}

func Get() ConfigFile {
	mu.RLock()
	defer mu.RUnlock()
	return cfg
}

func SetCourse(course [][]string, delcourses [][]string) {
	mu.Lock()
	cfg.Course = course
	cfg.DelCourses = delcourses
	mu.Unlock()
}

func UpdateAt(idx int, course []string) {
	mu.Lock()
	defer mu.Unlock()
	if idx >= 0 && idx < len(cfg.Course) {
		cfg.Course[idx] = course
	}
}
