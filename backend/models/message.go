package models

import "gorm.io/gorm"

type Message struct {
	gorm.Model
	GroupID    uint   `json:"group_id"`
	UserID     uint   `json:"user_id"`
	Alias      string `json:"alias"`
	SenderRole string `json:"sender_role"` // role of the sender at time of message
	Content    string `json:"content"`
}
