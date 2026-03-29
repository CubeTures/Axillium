package handlers

import (
	"net/http"
	"strconv"
	"strings"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func UploadProfilePicture(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		userID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user id"})
			return
		}

		var body struct {
			// Base64-encoded data URL, e.g. "data:image/jpeg;base64,/9j/4AAQ..."
			ImageData string `json:"image_data" binding:"required"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "image_data is required"})
			return
		}

		// Accept only data URLs so the client can't push arbitrary strings.
		if !strings.HasPrefix(body.ImageData, "data:image/") {
			c.JSON(http.StatusBadRequest, gin.H{"error": "image_data must be a data URL"})
			return
		}

		if err := db.Model(&models.User{}).
			Where("id = ?", userID).
			Update("profile_picture", body.ImageData).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save picture"})
			return
		}

		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	}
}
