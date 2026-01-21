namespace Project_65133295.Models
{
    using System;
    using System.Collections.Generic;
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using System.Data.Entity.Spatial;

    public partial class Notifications
    {
        [Key]
        public int NotificationID { get; set; }

        public int RecipientID { get; set; }

        public int? SenderID { get; set; }

        [Required]
        [StringLength(200)]
        public string Title { get; set; }

        public string Message { get; set; }

        [StringLength(50)]
        public string Type { get; set; }

        [StringLength(50)]
        public string RelatedEntityType { get; set; }

        public int? RelatedEntityID { get; set; }

        public bool? IsRead { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? ReadAt { get; set; }

        public virtual Users Users { get; set; }

        public virtual Users Users1 { get; set; }
    }
}
