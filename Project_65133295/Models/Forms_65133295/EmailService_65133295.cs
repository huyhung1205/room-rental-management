using System;
using System.Configuration;
using System.Net;
using System.Net.Mail;
using System.Text;
using System.Web;

namespace Project_65133295.Models.Forms_65133295
{
    public class EmailService_65133295
    {
        public static void SendVerificationEmail(string toEmail, string userName, string token)
        {
            try
            {
                string host = ConfigurationManager.AppSettings["EmailHost"];
                int port = int.Parse(ConfigurationManager.AppSettings["EmailPort"]);
                string user = ConfigurationManager.AppSettings["EmailUser"];
                string pass = ConfigurationManager.AppSettings["EmailPassword"];
                string senderName = ConfigurationManager.AppSettings["EmailSenderName"];

                string verifyUrl = HttpContext.Current.Request.Url.GetLeftPart(UriPartial.Authority) + "/Guest_65133295/VerifyEmail?token=" + token;

                string body = $@"
                    <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #facc15; border-radius: 10px; overflow: hidden;'>
                        <div style='background-color: #facc15; padding: 20px; text-align: center;'>
                            <h1 style='color: white; margin: 0;'>ThanhThao Stay</h1>
                        </div>
                        <div style='padding: 30px; background-color: #ffffff;'>
                            <h2 style='color: #333;'>Welcome {userName},</h2>
                            <p style='color: #666; font-size: 16px; line-height: 1.5;'>
                                Thank you for registering at <strong>ThanhThao Stay</strong>. 
                                To start searching and booking rooms, please verify your email address by clicking the button below:
                            </p>
                            <div style='text-align: center; margin: 30px 0;'>
                                <a href='{verifyUrl}' style='background-color: #facc15; color: white; padding: 15px 30px; text-decoration: none; font-weight: bold; border-radius: 5px; display: inline-block;'>VERIFY EMAIL</a>
                            </div>
                            <p style='color: #999; font-size: 12px;'>
                                This link will expire after 24 hours. If you did not register, please ignore this email.
                            </p>
                        </div>
                        <div style='background-color: #f9f9f9; padding: 20px; text-align: center; color: #999; font-size: 12px; border-top: 1px solid #eee;'>
                            &copy; {DateTime.Now.Year} ThanhThao Stay - Reliable room rental management system
                        </div>
                    </div>";

                using (MailMessage mail = new MailMessage())
                {
                    mail.From = new MailAddress(user, senderName);
                    mail.To.Add(toEmail);
                    mail.Subject = "Verify your account - ThanhThao Stay";
                    mail.Body = body;
                    mail.IsBodyHtml = true;
                    mail.BodyEncoding = Encoding.UTF8;

                    using (SmtpClient smtp = new SmtpClient(host, port))
                    {
                        smtp.Credentials = new NetworkCredential(user, pass);
                        smtp.EnableSsl = true;
                        smtp.Send(mail);
                    }
                }
            }
            catch (Exception ex)
            {
                // In production, log this error
                throw new Exception("Error sending verification email: " + ex.Message);
            }
        }
        public static void SendPasswordResetEmail(string toEmail, string userName, string token)
        {
            try
            {
                string host = ConfigurationManager.AppSettings["EmailHost"];
                int port = int.Parse(ConfigurationManager.AppSettings["EmailPort"]);
                string user = ConfigurationManager.AppSettings["EmailUser"];
                string pass = ConfigurationManager.AppSettings["EmailPassword"];
                string senderName = ConfigurationManager.AppSettings["EmailSenderName"];

                string resetUrl = HttpContext.Current.Request.Url.GetLeftPart(UriPartial.Authority) + "/Guest_65133295/ResetPassword?token=" + token + "&email=" + HttpUtility.UrlEncode(toEmail);

                string body = $@"
                    <div style='font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; border: 1px solid #facc15; border-radius: 10px; overflow: hidden;'>
                        <div style='background-color: #facc15; padding: 20px; text-align: center;'>
                            <h1 style='color: white; margin: 0;'>ThanhThao Stay</h1>
                        </div>
                        <div style='padding: 30px; background-color: #ffffff;'>
                            <h2 style='color: #333;'>Hello {userName},</h2>
                            <p style='color: #666; font-size: 16px; line-height: 1.5;'>
                                You received this email because we received a password reset request for your account at <strong>ThanhThao Stay</strong>.
                                Please click the button below to set a new password:
                            </p>
                            <div style='text-align: center; margin: 30px 0;'>
                                <a href='{resetUrl}' style='background-color: #facc15; color: white; padding: 15px 30px; text-decoration: none; font-weight: bold; border-radius: 5px; display: inline-block;'>RESET PASSWORD</a>
                            </div>
                            <p style='color: #999; font-size: 12px;'>
                                This link will expire after 24 hours. If you did not request a password reset, please ignore this email.
                            </p>
                        </div>
                        <div style='background-color: #f9f9f9; padding: 20px; text-align: center; color: #999; font-size: 12px; border-top: 1px solid #eee;'>
                            &copy; {DateTime.Now.Year} ThanhThao Stay - Reliable room rental management system
                        </div>
                    </div>";

                using (MailMessage mail = new MailMessage())
                {
                    mail.From = new MailAddress(user, senderName);
                    mail.To.Add(toEmail);
                    mail.Subject = "Password reset request - ThanhThao Stay";
                    mail.Body = body;
                    mail.IsBodyHtml = true;
                    mail.BodyEncoding = Encoding.UTF8;

                    using (SmtpClient smtp = new SmtpClient(host, port))
                    {
                        smtp.Credentials = new NetworkCredential(user, pass);
                        smtp.EnableSsl = true;
                        smtp.Send(mail);
                    }
                }
            }
            catch (Exception ex)
            {
                throw new Exception("Error sending password reset email: " + ex.Message);
            }
        }
    }
}
