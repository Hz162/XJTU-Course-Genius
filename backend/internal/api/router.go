package api

import (
	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/cors"
)

func NewRouter() *chi.Mux {
	s := NewServer()

	r := chi.NewRouter()
	r.Use(middleware.Logger)
	r.Use(middleware.Recoverer)
	r.Use(cors.Handler(cors.Options{
		AllowedOrigins:   []string{"*"},
		AllowedMethods:   []string{"GET", "POST", "PUT", "DELETE", "OPTIONS"},
		AllowedHeaders:   []string{"Accept", "Authorization", "Content-Type"},
		AllowCredentials: true,
		MaxAge:           300,
	}))

	r.Route("/api", func(r chi.Router) {
		r.Post("/login", s.HandleLogin)
		r.Post("/account/choose", s.HandleChooseAccount)
		r.Get("/captcha", s.HandleCaptchaImage)
		r.Get("/session/check", s.HandleSessionCheck)
		r.Post("/relogin", s.HandleRelogin)

		r.Route("/mfa", func(r chi.Router) {
			r.Post("/init", s.HandleMFAInit)
			r.Post("/send", s.HandleMFASend)
			r.Post("/verify", s.HandleMFAVerify)
		})

		r.Get("/batches", s.HandleBatches)
		r.Post("/batches/select", s.HandleEnterRound)

		r.Get("/courses/selected", s.HandleSelectedCourses)
		r.Get("/courses/query/{type}", s.HandleQueryCourses) // type: TJKC, FANKC, FAWKC, XGXK, TYKC

		r.Get("/campus", s.HandleCampusList)
		r.Post("/campus/set", s.HandleCampusSet)

		r.Route("/selection", func(r chi.Router) {
			r.Post("/start", s.HandleSelectionStart)
			r.Post("/stop", s.HandleSelectionStop)
			r.Get("/status", s.HandleSelectionStatus)
		})

		r.Get("/config", s.HandleConfigGet)
		r.Post("/config", s.HandleConfigSave)
	})

	return r
}
