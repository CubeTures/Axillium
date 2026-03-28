package routes

import (
	"github.com/cubetures/axillium/handlers"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func Register(r *gin.Engine, db *gorm.DB) {
	api := r.Group("/api")

	auth := api.Group("/auth")
	{
		auth.POST("/register", handlers.Register(db))
		auth.POST("/login", handlers.Login(db))
	}

	groups := api.Group("/groups")
	{
		groups.GET("", handlers.GetGroups(db))
		groups.POST("", handlers.CreateGroup(db))
		groups.GET("/:id/messages", handlers.GetMessages(db))
		groups.POST("/:id/messages", handlers.SendMessage(db))
	}
}
