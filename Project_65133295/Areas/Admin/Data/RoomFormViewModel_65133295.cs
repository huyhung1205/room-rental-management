using System;
using System.Collections.Generic;
using System.Web;
using Project_65133295.Models;
using System.ComponentModel.DataAnnotations;

namespace Project_65133295.Areas.Admin.Data
{
    public class RoomFormViewModel_65133295
    {
        public int RoomID { get; set; }

        [Required(ErrorMessage = "Please enter room number")]
        [StringLength(50)]
        public string RoomNumber { get; set; }

        [Required(ErrorMessage = "Please enter posting title")]
        [StringLength(200)]
        public string Title { get; set; }

        public string Description { get; set; }

        [Required(ErrorMessage = "Please enter area")]
        [Range(0.01, 9999.99, ErrorMessage = "Area must be greater than 0")]
        public decimal? Area { get; set; }

        [Required(ErrorMessage = "Please enter rental price")]
        [Range(1000, 999999999, ErrorMessage = "Price must be from 1,000 VND and above")]
        public decimal Price { get; set; }

        public string PriceUnit { get; set; }

        [Required(ErrorMessage = "Please select building address")]
        public int AddressID { get; set; }
        public int? MaxOccupancy { get; set; }
        public int StatusID { get; set; }
        
        // For Select Lists
        public IEnumerable<Addresses> Addresses { get; set; }
        public IEnumerable<RoomStatuses> Statuses { get; set; }
        
        // For Utilities
        public List<UtilitySelection_65133295> Utilities { get; set; }
        
        // For Images
        public List<RoomImageViewModel_65133295> ExistingImages { get; set; }
        public List<HttpPostedFileBase> NewImages { get; set; }
    }

    public class UtilitySelection_65133295
    {
        public int UtilityID { get; set; }
        public string UtilityName { get; set; }
        public bool IsSelected { get; set; }
    }

    public class RoomImageViewModel_65133295
    {
        public int ImageID { get; set; }
        public string ImageURL { get; set; }
        public bool IsPrimary { get; set; }
        public bool IsDeleted { get; set; }
    }
}
