package routes

import (
	"github.com/cubetures/axillium/handlers"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func Register(r *gin.Engine, db *gorm.DB) {
	api := r.Group("/api")

	groups := api.Group("/groups")
	{
		groups.GET("/:id/messages", handlers.GetMessages(db))
		groups.POST("/:id/messages", handlers.SendMessage(db))
	}
}
