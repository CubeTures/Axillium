package handlers

import (
	"errors"
	"net/http"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"golang.org/x/crypto/bcrypt"
	"gorm.io/gorm"
)

func Register(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			PhoneNumber string `json:"phone_number"`
			Password    string `json:"password"`
			Alias       string `json:"alias"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if body.PhoneNumber == "" || body.Password == "" || body.Alias == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "phone_number, password, and alias are required"})
			return
		}

		hash, err := bcrypt.GenerateFromPassword([]byte(body.Password), bcrypt.DefaultCost)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to process password"})
			return
		}

		user := models.User{
			PhoneNumber: body.PhoneNumber,
			Password:    string(hash),
			Alias:       body.Alias,
		}
		if err := db.Create(&user).Error; err != nil {
			c.JSON(http.StatusConflict, gin.H{"error": "phone number already registered"})
			return
		}

		c.JSON(http.StatusCreated, models.AuthResponse{ID: user.ID, Alias: user.Alias})
	}
}

func Login(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			PhoneNumber string `json:"phone_number"`
			Password    string `json:"password"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		if body.PhoneNumber == "" || body.Password == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "phone_number and password are required"})
			return
		}

		var user models.User
		if err := db.Where("phone_number = ?", body.PhoneNumber).First(&user).Error; err != nil {
			if errors.Is(err, gorm.ErrRecordNotFound) {
				c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
			} else {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "login failed"})
			}
			return
		}

		if err := bcrypt.CompareHashAndPassword([]byte(user.Password), []byte(body.Password)); err != nil {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid credentials"})
			return
		}

		c.JSON(http.StatusOK, models.AuthResponse{ID: user.ID, Alias: user.Alias})
	}
}
