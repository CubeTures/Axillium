package models

import (
	"time"

	"gorm.io/gorm"
)

type Meeting struct {
	gorm.Model
	GroupID         uint      `json:"group_id"`
	Title           string    `json:"title"`
	Location        string    `json:"location"`
	Note            string    `json:"note"`
	ScheduledAt     time.Time `json:"scheduled_at"`
	CreatedByID     uint      `json:"created_by_id"`
	CreatedByAlias  string    `json:"created_by_alias"`
	CreatedByRole   string    `json:"created_by_role"`
}
