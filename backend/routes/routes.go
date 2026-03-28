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
		groups.GET("/:id/messages", handlers.GetMessages(db))
		groups.POST("/:id/messages", handlers.SendMessage(db))
		groups.GET("/:id/featured-posts", handlers.GetGroupFeaturedPosts(db))
		groups.POST("/:id/featured-posts", handlers.FeaturePostForGroup(db))
		groups.DELETE("/:id/featured-posts/:post_id", handlers.UnfeaturePostForGroup(db))
	}

	posts := api.Group("/posts")
	{
		posts.GET("", handlers.ListPosts(db))
		posts.GET("/:id", handlers.GetPost(db))
		posts.POST("", handlers.CreatePost(db))
	}
}
