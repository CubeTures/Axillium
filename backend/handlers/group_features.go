package handlers

import (
	"net/http"
	"strconv"

	"github.com/cubetures/axillium/models"
	"github.com/gin-gonic/gin"
	"gorm.io/gorm"
)

var featureRoles = map[string]bool{
	"leader":  true,
	"sponsor": true,
}

func GetGroupFeaturedPosts(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid group id"})
			return
		}

		var features []models.GroupFeature
		if err := db.Where("group_id = ? AND featured_week = ?", groupID, currentISOWeek()).
			Find(&features).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load featured posts"})
			return
		}

		if len(features) == 0 {
			c.JSON(http.StatusOK, []models.Post{})
			return
		}

		postIDs := make([]uint, len(features))
		for i, f := range features {
			postIDs[i] = f.PostID
		}

		var posts []models.Post
		if err := db.Where("id IN ? AND status = ?", postIDs, "published").
			Order("created_at desc").Find(&posts).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to load posts"})
			return
		}
		c.JSON(http.StatusOK, posts)
	}
}

func FeaturePostForGroup(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid group id"})
			return
		}

		var body struct {
			PostID       uint   `json:"post_id"`
			FeaturerID   uint   `json:"featurer_id"`
			FeaturerRole string `json:"featurer_role"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}
		if !featureRoles[body.FeaturerRole] {
			c.JSON(http.StatusForbidden, gin.H{"error": "only leaders and sponsors can feature posts"})
			return
		}

		// Replace any existing feature for this post in this group
		db.Where("post_id = ? AND group_id = ?", body.PostID, groupID).
			Delete(&models.GroupFeature{})

		feature := models.GroupFeature{
			PostID:       body.PostID,
			GroupID:      uint(groupID),
			FeaturedByID: body.FeaturerID,
			FeaturedWeek: currentISOWeek(),
		}
		if err := db.Create(&feature).Error; err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to feature post"})
			return
		}
		c.JSON(http.StatusOK, gin.H{"featured_week": currentISOWeek()})
	}
}

func UnfeaturePostForGroup(db *gorm.DB) gin.HandlerFunc {
	return func(c *gin.Context) {
		groupID, err := strconv.ParseUint(c.Param("id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid group id"})
			return
		}
		postID, err := strconv.ParseUint(c.Param("post_id"), 10, 64)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid post id"})
			return
		}

		var body struct {
			FeaturerRole string `json:"featurer_role"`
		}
		if err := c.ShouldBindJSON(&body); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid request"})
			return
		}
		if !featureRoles[body.FeaturerRole] {
			c.JSON(http.StatusForbidden, gin.H{"error": "only leaders and sponsors can unfeature posts"})
			return
		}

		db.Where("post_id = ? AND group_id = ? AND featured_week = ?",
			postID, groupID, currentISOWeek()).
			Delete(&models.GroupFeature{})

		c.JSON(http.StatusOK, gin.H{"status": "unfeatured"})
	}
}
