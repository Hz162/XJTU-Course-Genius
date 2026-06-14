package course

import (
	"context"
	"fmt"
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
	courses    [][]string // [teachingClassID, courseName, teacherName, teachingPlace, classType, campus]
	delCourses [][]string // conflict course IDs to delete before grabbing
	flags      []int      // 0=not yet, 1=done
	logs       []string
	attempts   []int      // per-course attempt count
	lastLogs   []string   // per-course last status (to avoid spam)
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
	e.attempts = make([]int, len(e.courses))
	e.lastLogs = make([]string, len(e.courses))
	e.logs = make([]string, 0)
	e.ctx, e.cancel = context.WithCancel(context.Background())
	e.mu.Unlock()

	e.addLog(fmt.Sprintf("开始抢课 — 共 %d 门课程", len(e.courses)))
	for i, c := range e.courses {
		name := c[0]
		if len(c) > 1 {
			name = c[1]
		}
		e.addLog(fmt.Sprintf("  [%d] %s — %s", i+1, name, c[0]))
	}

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
	client := session.NewClient()
	client.SetHeader("Token", session.Get().Token)

	round := 0

	for {
		select {
		case <-e.ctx.Done():
			return
		default:
		}

		round++

		// Re-login every ~10 minutes (2000 rounds * 300ms)
		if round%2000 == 0 {
			e.addLog("保活：重新登录...")
			if err := auth.ReloginIfNeeded(client); err != nil {
				e.addLog("重登录失败: " + err.Error())
				time.Sleep(1 * time.Second)
				continue
			}
			e.addLog("登录状态正常")
		}

		e.mu.Lock()
		courses := make([][]string, len(e.courses))
		copy(courses, e.courses)
		delCourses := make([][]string, len(e.delCourses))
		copy(delCourses, e.delCourses)
		flags := make([]int, len(e.flags))
		copy(flags, e.flags)
		attempts := make([]int, len(e.attempts))
		copy(attempts, e.attempts)
		lastLogs := make([]string, len(e.lastLogs))
		copy(lastLogs, e.lastLogs)
		e.mu.Unlock()

		anyChange := false

		for j := range courses {
			select {
			case <-e.ctx.Done():
				return
			default:
			}

			if j >= len(flags) || flags[j] == 1 {
				continue
			}

			e.mu.Lock()
			e.attempts[j]++
			attemptNum := e.attempts[j]
			e.mu.Unlock()

			// Log first attempt, then every 50th
			if attemptNum == 1 || attemptNum%50 == 0 {
				name := courses[j][0]
				if len(courses[j]) > 1 {
					name = courses[j][1]
				}
				e.addLog(fmt.Sprintf("[%s] 第 %d 次尝试...", name, attemptNum))
			}

			hasCapacity, err := CheckCapacity(client, courses[j][0])
			if err != nil {
				// Log capacity errors every 50 attempts to avoid spam
				if attemptNum%50 == 0 {
					e.addLog(fmt.Sprintf("[%s] 容量查询失败: %v", courses[j][0], err))
				}
				continue
			}
			if !hasCapacity {
				continue
			}

			// Has capacity! Delete conflicts
			if j < len(delCourses) {
				for _, dc := range delCourses[j] {
					DeleteVolunteer(client, dc)
				}
			}

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
				if attemptNum%10 == 0 {
					e.addLog(fmt.Sprintf("[%s] 选课失败: %v", courses[j][0], err))
				}
				continue
			}

			// Success
			e.mu.Lock()
			if j < len(e.flags) {
				e.flags[j] = 1
			}
			e.mu.Unlock()

			name := courses[j][0]
			if len(courses[j]) > 1 {
				name = courses[j][1]
			}
			e.addLog(fmt.Sprintf("✓ [%s] %s 抢课成功！(第 %d 次尝试)",
				name, courses[j][0], attemptNum))
			anyChange = true
		}

		// Check if all done
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
			e.addLog("🎉 所有课程抢课完成！")
			e.Stop()
			return
		}

		// Status summary every 10 rounds
		if round%10 == 0 && anyChange {
			e.mu.Lock()
			done := 0
			for _, f := range e.flags {
				if f == 1 {
					done++
				}
			}
			e.mu.Unlock()
			e.addLog(fmt.Sprintf("进度: %d/%d", done, len(courses)))
		}

		time.Sleep(300 * time.Millisecond)
	}
}

func (e *Engine) addLog(msg string) {
	e.mu.Lock()
	defer e.mu.Unlock()
	t := time.Now().Format("15:04:05")
	e.logs = append(e.logs, "["+t+"] "+msg)
	if len(e.logs) > 500 {
		e.logs = e.logs[len(e.logs)-500:]
	}
}
