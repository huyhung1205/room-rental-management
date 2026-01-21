namespace Project_65133295.Models
{
    using System;
    using System.Collections.Generic;
    using System.ComponentModel.DataAnnotations;
    using System.ComponentModel.DataAnnotations.Schema;
    using System.Data.Entity.Spatial;

    public partial class Payments
    {
        public Payments()
        {
            Fees = new HashSet<Fees>();
        }

        [Key]
        public int PaymentID { get; set; }

        public int ContractID { get; set; }

        [ForeignKey("Users1")]
        public int UserID { get; set; }

        [ForeignKey("Users")]
        public int AdminID { get; set; }

        [Required]
        [StringLength(50)]
        public string InvoiceNumber { get; set; }

        [Column(TypeName = "date")]
        public DateTime PaymentDate { get; set; }

        public decimal Amount { get; set; }

        [StringLength(30)]
        public string PaymentStatus { get; set; }

        [StringLength(50)]
        public string PaymentMethod { get; set; }

        public DateTime? DueDate { get; set; }

        public DateTime? PaidDate { get; set; }

        public string Notes { get; set; }

        public DateTime? CreatedAt { get; set; }

        public DateTime? UpdatedAt { get; set; }

        public virtual Contracts Contracts { get; set; }

        [System.Diagnostics.CodeAnalysis.SuppressMessage("Microsoft.Usage", "CA2227:CollectionPropertiesShouldBeReadOnly")]
        public virtual ICollection<Fees> Fees { get; set; }

        public virtual Users Users { get; set; }

        public virtual Users Users1 { get; set; }
    }
}
