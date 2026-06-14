package course

import (
	"context"
	"sync"
	"time"

	"xjtu-course-genius/internal/auth"
	"xjtu-course-genius/internal/session"

	"github.com/go-resty/resty/v2"
)

type Engine struct {
	client *resty.Client

	mu         sync.Mutex
	running    bool
	courses    [][]string   // [teachingClassID, courseName, teacherName, teachingPlace, classType, campus]
	delCourses [][]string   // conflict course IDs to delete before grabbing
	flags      []int        // 0=not yet, 1=done
	logs       []string
	ctx        context.Context
	cancel     context.CancelFunc
}

func NewEngine(client *resty.Client) *Engine {
	return &Engine{client: client}
}

func (e *Engine) SetCourses(courses [][]string, delCourses [][]string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	e.courses = courses
	e.delCourses = delCourses
}

func (e *Engine) Status() SelectionStatus {
	e.mu.Lock()
	defer e.mu.Unlock()
	total := len(e.courses)
	logs := make([]string, len(e.logs))
	copy(logs, e.logs)
	flags := make([]int, len(e.flags))
	copy(flags, e.flags)
	done := 0
	for _, f := range flags {
		if f == 1 {
			done++
		}
	}
	return SelectionStatus{
		Running:     e.running,
		TotalCourse: total,
		Flags:       flags,
		Progress:    done,
		Log:         logs,
	}
}

func (e *Engine) Start() {
	e.mu.Lock()
	if e.running {
		e.mu.Unlock()
		return
	}
	e.running = true
	e.flags = make([]int, len(e.courses))
	e.logs = make([]string, 0)
	e.ctx, e.cancel = context.WithCancel(context.Background())
	e.mu.Unlock()

	go e.loop()
}

func (e *Engine) Stop() {
	e.mu.Lock()
	defer e.mu.Unlock()
	if !e.running {
		return
	}
	e.running = false
	if e.cancel != nil {
		e.cancel()
	}
}

func (e *Engine) loop() {
	client := session.NewClient() // fresh client for the loop
	client.SetHeader("Token", session.Get().Token)

	loopCount := 0

	for {
		select {
		case <-e.ctx.Done():
			return
		default:
		}

		loopCount++
		// every 4000 iterations (~400s at 0.1s interval), check & relogin
		if loopCount%4000 == 0 {
			if err := auth.ReloginIfNeeded(client); err != nil {
				e.addLog("重登录失败: " + err.Error())
				time.Sleep(1 * time.Second)
				continue
			}
		}

		e.mu.Lock()
		courses := make([][]string, len(e.courses))
		copy(courses, e.courses)
		delCourses := make([][]string, len(e.delCourses))
		copy(delCourses, e.delCourses)
		flags := make([]int, len(e.flags))
		copy(flags, e.flags)
		e.mu.Unlock()

		for j := range courses {
			select {
			case <-e.ctx.Done():
				return
			default:
			}

			if j >= len(flags) || flags[j] == 1 {
				continue
			}

			hasCapacity, err := CheckCapacity(client, courses[j][0])
			if err != nil {
				continue
			}
			if !hasCapacity {
				continue
			}

			// delete conflict courses first
			if j < len(delCourses) {
				for _, dc := range delCourses[j] {
					DeleteVolunteer(client, dc)
				}
			}

			// grab the course
			classType := ""
			campus := ""
			if len(courses[j]) > 4 {
				classType = courses[j][4]
			}
			if len(courses[j]) > 5 {
				campus = courses[j][5]
			} else {
				campus = session.Get().Campus
			}

			if err := Volunteer(client, courses[j][0], classType, campus); err != nil {
				continue
			}

			// mark as done
			e.mu.Lock()
			if j < len(e.flags) {
				e.flags[j] = 1
			}
			e.mu.Unlock()

			e.addLog("抢课成功: " + courses[j][1])
		}

		// check if all done
		e.mu.Lock()
		allDone := len(e.flags) > 0
		for _, f := range e.flags {
			if f == 0 {
				allDone = false
				break
			}
		}
		e.mu.Unlock()

		if allDone {
			e.addLog("所有课程抢课完成")
			e.Stop()
			return
		}

		time.Sleep(300 * time.Millisecond)
	}
}

func (e *Engine) addLog(msg string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	t := time.Now().Format("15:04:05")
	e.logs = append(e.logs, "["+t+"] "+msg)
	if len(e.logs) > 200 {
		e.logs = e.logs[len(e.logs)-200:]
	}
}
