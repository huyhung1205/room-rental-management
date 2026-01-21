namespace Project_65133295.Models
{
    using System;
    using System.Collections.Generic;
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using System.Data.Entity.Spatial;

    public partial class Fees
    {
        [Key]
        public int FeeID { get; set; }

        public int PaymentID { get; set; }

        [Required]
        [StringLength(100)]
        public string FeeName { get; set; }

        public decimal FeeAmount { get; set; }

        [StringLength(255)]
        public string Description { get; set; }

        public virtual Payments Payments { get; set; }
    }
}
