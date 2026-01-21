using System;
using System.ComponentModel.DataAnnotations;

namespace Project_65133295.Models.Forms_65133295
{
    public class ForgotPasswordViewModel_65133295
    {
        [Required(ErrorMessage = "Please enter email")]
        [EmailAddress(ErrorMessage = "Invalid email")]
        public string Email { get; set; }
    }
}
