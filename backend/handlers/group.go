package handlers

import (
	"net/http"
	"strings"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func GetGroups(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		location := strings.TrimSpace(c.Query("location"))

		var groups []models.Group
		query := db.Model(&models.Group{})
		if location != "" {
			query = query.Where("LOWER(location) LIKE LOWER(?)", "%"+location+"%")
		}
		if err := query.Find(&groups).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load groups"})
			return
		}

		c.JSON(http.StatusOK, groups)
	}
}

func CreateGroup(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			Name          string `json:"name"`
			AddictionType string `json:"addiction_type"`
			Location      string `json:"location"`
			LeaderID      uint   `json:"leader_id"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if body.AddictionType == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "addiction_type is required"})
			return
		}
		if body.Name == "" {
			body.Name = body.AddictionType + " Support Group"
		}

		group := models.Group{
			Name:          body.Name,
			AddictionType: body.AddictionType,
			Location:      body.Location,
			LeaderID:      body.LeaderID,
		}
		if err := db.Create(&group).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create group"})
			return
		}

		c.JSON(http.StatusCreated, group)
	}
}
