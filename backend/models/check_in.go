package models

import "gorm.io/gorm"

type CheckIn struct {
	gorm.Model
	UserID     uint   `json:"user_id"`
	MoodScore  int    `json:"mood_score"` // 1–5 Likert scale
	Relapsed   bool   `json:"relapsed"`
	Reflection string `json:"reflection"` // filled when relapsed
}
