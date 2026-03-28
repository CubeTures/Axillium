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
		groups.GET("/:id/members", handlers.GetGroupMembers(db))
		groups.GET("/:id/sponsors", handlers.GetAvailableSponsors(db))
	}

	api.POST("/check-ins", handlers.CreateCheckIn(db))
	api.GET("/check-ins/:user_id", handlers.GetCheckIns(db))
	api.GET("/check-ins/:user_id/today", handlers.GetTodayCheckIn(db))

	users := api.Group("/users")
	{
		users.POST("/:id/sponsor", handlers.RequestSponsor(db))
	}
}
