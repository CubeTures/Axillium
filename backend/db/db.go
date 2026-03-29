package db

import (
	"log"

	"github.com/cubetures/axillium/models"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

var DB *gorm.DB

func Init() {
	var err error
	DB, err = gorm.Open(sqlite.Open("app.db"), &gorm.Config{})
	if err != nil {
		log.Fatal("failed to connect to database:", err)
	}

	DB.AutoMigrate(&models.User{}, &models.Group{}, &models.Message{}, &models.CheckIn{}, &models.Notification{}, &models.Post{}, &models.GroupFeature{}, &models.DirectMessage{})
	Seed(DB)
}
