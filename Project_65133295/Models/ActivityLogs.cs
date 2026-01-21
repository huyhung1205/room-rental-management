namespace Project_65133295.Models
{
    using System;
    using System.Collections.Generic;
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using System.Data.Entity.Spatial;

    public partial class ActivityLogs
    {
        [Key]
        public int LogID { get; set; }

        public int? UserID { get; set; }

        [Required]
        [StringLength(100)]
        public string ActionType { get; set; }

        [StringLength(50)]
        public string EntityType { get; set; }

        public int? EntityID { get; set; }

        public string OldValues { get; set; }

        public string NewValues { get; set; }

        [StringLength(45)]
        public string IPAddress { get; set; }

        public string Description { get; set; }

        public DateTime? CreatedAt { get; set; }

        public virtual Users Users { get; set; }
    }
}
