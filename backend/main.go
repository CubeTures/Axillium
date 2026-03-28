package main

import (
	"net/http"

	"github.com/cubetures/axillium/db"
	"github.com/cubetures/axillium/routes"
	"github.com/gin-gonic/gin"
)

func main() {
	db.Init()

	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	routes.Register(r, db.DB)

	r.Run(":8080")
}
