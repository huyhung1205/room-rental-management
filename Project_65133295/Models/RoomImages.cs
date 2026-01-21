namespace Project_65133295.Models
{
    using System;
    using System.Collections.Generic;
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using System.Data.Entity.Spatial;

    public partial class RoomImages
    {
        [Key]
        public int ImageID { get; set; }

        public int RoomID { get; set; }

        [StringLength(500)]
        public string ImageUrl { get; set; }

        public int? DisplayOrder { get; set; }

        public bool? IsMainImage { get; set; }

        public DateTime? UploadedAt { get; set; }

        public virtual Rooms Rooms { get; set; }
    }
}
