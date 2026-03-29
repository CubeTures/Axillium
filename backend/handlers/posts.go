package handlers

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

func currentISOWeek() string {
	year, week := time.Now().ISOWeek()
	return fmt.Sprintf("%d-W%02d", year, week)
}

var allowedAuthorRoles = map[string]bool{
	"sponsor":    true,
	"leader":     true,
	"influencer": true,
}

func ListPosts(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		page := 1
		if p := c.Query("page"); p != "" {
			if n, err := strconv.Atoi(p); err == nil && n > 0 {
				page = n
			}
		}
		offset := (page - 1) * 20

		query := db.Where("status = ?", "published")
		if q := c.Query("addiction_type"); q != "" {
			query = query.Where("addiction_type = ?", q)
		}
		if q := c.Query("title"); q != "" {
			query = query.Where("title LIKE ?", "%"+q+"%")
		}

		var posts []models.Post
		if err := query.Order("created_at desc").Limit(20).Offset(offset).Find(&posts).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load posts"})
			return
		}
		c.JSON(http.StatusOK, posts)
	}
}

func GetPost(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.Param("id")
		var post models.Post
		if err := db.Where("id = ? AND status = ?", id, "published").First(&post).Error; err != nil {
			c.JSON(http.StatusNotFound, gin.H{"error": "post not found"})
			return
		}
		c.JSON(http.StatusOK, post)
	}
}

func CreatePost(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		var body struct {
			AuthorID      uint   `json:"author_id"`
			AuthorAlias   string `json:"author_alias"`
			AuthorRole    string `json:"author_role"`
			AddictionType string `json:"addiction_type"`
			Title         string `json:"title"`
			Content       string `json:"content"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}
		if body.Title == "" || body.Content == "" || body.AuthorAlias == "" {
			c.JSON(http.StatusBadRequest, gin.H{"error": "title, content, and author_alias are required"})
			return
		}
		if !allowedAuthorRoles[body.AuthorRole] {
			c.JSON(http.StatusForbidden, gin.H{"error": "only sponsors, leaders, and influencers can create posts"})
			return
		}
		post := models.Post{
			AuthorID:      body.AuthorID,
			AuthorAlias:   body.AuthorAlias,
			AddictionType: body.AddictionType,
			Title:         body.Title,
			Content:       body.Content,
			Status:        "published",
		}
		if err := db.Create(&post).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to create post"})
			return
		}
		c.JSON(http.StatusCreated, post)
	}
}


