using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using System.Data.Entity;
using Project_65133295.Models;

using Project_65133295.Controllers;

namespace Project_65133295.Areas.User.Controllers
{
    [CustomAuthorize(Role = "User")]
    public class User_65133295Controller : Controller
    {
        // GET: User/User_65133295

        DbContext_65133295 db = new DbContext_65133295();

        protected override void OnActionExecuting(ActionExecutingContext filterContext)
        {
            if (Session["UserID"] != null)
            {
                int userId = Convert.ToInt32(Session["UserID"]);
                ViewBag.UnreadCount = db.Notifications.Count(n => n.RecipientID == userId && n.IsRead != true);
            }
            base.OnActionExecuting(filterContext);
        }

        [ChildActionOnly]
        public ActionResult RenderNotificationBadge()
        {
            if (Session["UserID"] == null) return Content("");
            int userId = Convert.ToInt32(Session["UserID"]);
            int count = db.Notifications.Count(n => n.RecipientID == userId && n.IsRead != true);
            return PartialView("_NotificationBadge", count);
        }

        // User Area Dashboard
        public ActionResult Index()
        {
            if (Session["UserID"] == null)
            {
                return RedirectToAction("Login", "Guest_65133295", new { area = "" });
            }

            int userId = (int)Session["UserID"];

            // 1. Stats
            var bookings = db.Bookings.Where(b => b.UserID == userId).ToList();
            var payments = db.Payments.Where(p => p.UserID == userId).ToList();

            ViewBag.TotalBookings = bookings.Count;
            ViewBag.PendingBookings = bookings.Count(b => b.BookingStatus == "Pending");
            ViewBag.UnpaidInvoices = payments.Count(p => p.PaymentStatus == "Pending");
            ViewBag.TotalSpent = payments.Where(p => p.PaymentStatus == "Paid").Sum(p => (decimal?)p.Amount) ?? 0;

            // 2. Recent Bookings (Top 5)
            ViewBag.RecentBookings = db.Bookings
                .Include("Rooms")
                .Where(b => b.UserID == userId)
                .OrderByDescending(b => b.CreatedAt)
                .Take(5)
                .ToList();

            // 3. Recent Invoices (Top 5)
            ViewBag.RecentInvoices = db.Payments
                .Where(p => p.UserID == userId)
                .OrderByDescending(p => p.PaymentDate)
                .Take(5)
                .ToList();

            return View();
        }

        // Manage Personal Profile
        public new ActionResult Profile()
        {
            if (Session["UserID"] == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });
            int userId = (int)Session["UserID"];

            var user = db.Users.Include(u => u.Addresses).FirstOrDefault(u => u.UserID == userId);
            if (user == null) return HttpNotFound();
            
            // Sync Session data
            Session["FullName"] = $"{user.FirstName} {user.LastName}".Trim();
            Session["Avatar"] = user.Avatar;

            return View(user);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult UpdateProfile(Users model, HttpPostedFileBase AvatarFile, string Street, string Ward, string District, string City)
        {
            if (Session["UserID"] == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });
            int userId = (int)Session["UserID"];

            var user = db.Users.Include(u => u.Addresses).FirstOrDefault(u => u.UserID == userId);
            if (user == null) return HttpNotFound();

            // Track old values for logging
            string oldValues = $"Name: {user.FirstName} {user.LastName}, Phone: {user.PhoneNumber}, Avatar: {user.Avatar}";

            // Update Basic Info
            user.FirstName = model.FirstName;
            user.LastName = model.LastName;
            user.PhoneNumber = model.PhoneNumber;

            // Handle Avatar Upload
            if (AvatarFile != null && AvatarFile.ContentLength > 0)
            {
                try
                {
                    string fileName = Guid.NewGuid().ToString() + System.IO.Path.GetExtension(AvatarFile.FileName);
                    string path = System.IO.Path.Combine(Server.MapPath("~/public/avatars"), fileName);
                    
                    // Ensure directory exists
                    string dir = Server.MapPath("~/public/avatars");
                    if (!System.IO.Directory.Exists(dir)) System.IO.Directory.CreateDirectory(dir);

                    AvatarFile.SaveAs(path);
                    user.Avatar = "/public/avatars/" + fileName;
                }
                catch (Exception ex)
                {
                    TempData["ErrorMessage"] = "Error uploading avatar: " + ex.Message;
                }
            }

            // Handle Address
            if (user.Addresses == null)
            {
                user.Addresses = new Addresses
                {
                    Street = Street ?? "",
                    Ward = Ward ?? "",
                    District = District ?? "",
                    City = City ?? "",
                    CreatedAt = DateTime.Now
                };
            }
            else
            {
                user.Addresses.Street = Street ?? "";
                user.Addresses.Ward = Ward ?? "";
                user.Addresses.District = District ?? "";
                user.Addresses.City = City ?? "";
            }

            user.UpdatedAt = DateTime.Now;

            // Record Activity Log
            var log = new ActivityLogs
            {
                UserID = userId,
                ActionType = "Update",
                EntityType = "Users",
                EntityID = userId,
                Description = "Updated personal information",
                OldValues = oldValues,
                NewValues = $"Name: {user.FirstName} {user.LastName}, Phone: {user.PhoneNumber}, Avatar: {user.Avatar}",
                CreatedAt = DateTime.Now,
                IPAddress = Request.UserHostAddress
            };
            db.ActivityLogs.Add(log);

            db.SaveChanges();
            
            // Update session for layout
            Session["Avatar"] = user.Avatar;
            Session["FullName"] = user.FirstName + " " + user.LastName;

            TempData["SuccessMessage"] = "Profile updated successfully!";
            return RedirectToAction("Profile");
        }

        // Search & Book Rooms
        public ActionResult SearchAndBook(string query, decimal? minPrice, decimal? maxPrice, decimal? minArea, decimal? maxArea, int[] selectedUtilities, string sortOrder, int page = 1)
        {
            if (Session["UserID"] == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });
            int userId = (int)Session["UserID"];
            int pageSize = 6;

            // 0. Get user's active bookings to hide them from search (avoid confusion)
            var bookedRoomIds = db.Bookings
                .Where(b => b.UserID == userId && (b.BookingStatus == "Pending" || b.BookingStatus == "Approved"))
                .Select(b => b.RoomID)
                .ToList();

            // 1. Base Query
            // Show Available rooms (1) OR Reserved rooms (4) that belong to the current user
            var rooms = db.Rooms.Include(r => r.Addresses)
                               .Include(r => r.RoomImages)
                               .Include(r => r.RoomStatuses)
                               .Include(r => r.RoomUtilities.Select(ru => ru.Utilities))
                               .Where(r => r.StatusID == 1 || (r.StatusID == 4 && db.Bookings.Any(b => b.RoomID == r.RoomID && b.UserID == userId && b.BookingStatus == "Pending")));

            // 2. Filter by search criteria
            if (!string.IsNullOrEmpty(query))
            {
                string term = query.Trim().ToLower();
                rooms = rooms.Where(r => r.RoomNumber.ToLower().Contains(term) ||
                                         r.Title.ToLower().Contains(term) || 
                                         r.Description.ToLower().Contains(term) || 
                                         r.Addresses.City.ToLower().Contains(term) || 
                                         r.Addresses.District.ToLower().Contains(term) ||
                                         r.Addresses.Ward.ToLower().Contains(term) ||
                                         r.Addresses.Street.ToLower().Contains(term));
            }

            if (minPrice.HasValue) rooms = rooms.Where(r => r.Price >= minPrice.Value);
            if (maxPrice.HasValue) rooms = rooms.Where(r => r.Price <= maxPrice.Value);
            if (minArea.HasValue) rooms = rooms.Where(r => r.Area >= minArea.Value);
            if (maxArea.HasValue) rooms = rooms.Where(r => r.Area <= maxArea.Value);

            if (selectedUtilities != null && selectedUtilities.Length > 0)
            {
                foreach (var utilId in selectedUtilities)
                {
                    rooms = rooms.Where(r => r.RoomUtilities.Any(u => u.UtilityID == utilId));
                }
            }

            // 3. Sorting
            ViewBag.CurrentSort = sortOrder;
            switch (sortOrder)
            {
                case "price_asc": rooms = rooms.OrderBy(r => r.Price); break;
                case "price_desc": rooms = rooms.OrderByDescending(r => r.Price); break;
                default: rooms = rooms.OrderByDescending(r => r.CreatedAt); break; // Newest first
            }

            // 4. Pagination
            int totalItems = rooms.Count();
            int totalPages = (int)Math.Ceiling((double)totalItems / pageSize);
            page = Math.Max(1, Math.Min(page, totalPages > 0 ? totalPages : 1));
            var pagedRooms = rooms.Skip((page - 1) * pageSize).Take(pageSize).ToList();

            // 5. ViewBag Data
            ViewBag.Utilities = db.Utilities.ToList();
            ViewBag.Query = query;
            ViewBag.MinPrice = minPrice;
            ViewBag.MaxPrice = maxPrice;
            ViewBag.MinArea = minArea;
            ViewBag.MaxArea = maxArea;
            ViewBag.SelectedUtilities = selectedUtilities;
            ViewBag.Page = page;
            ViewBag.TotalPages = totalPages;
            ViewBag.TotalItems = totalItems;
            ViewBag.SortOrder = sortOrder;
            ViewBag.BookedRoomIds = bookedRoomIds;

            return View(pagedRooms);
        }

        // View Room Details
        public ActionResult RoomDetails(int? id)
        {
            if (id == null) return RedirectToAction("SearchAndBook");

            var room = db.Rooms.Include(r => r.Addresses)
                               .Include(r => r.RoomImages)
                               .Include(r => r.RoomUtilities.Select(ru => ru.Utilities))
                               .Include(r => r.Users)
                               .Include(r => r.Reviews.Select(rv => rv.Users))
                               .Include(r => r.RoomStatuses)
                               .FirstOrDefault(r => r.RoomID == id);

            if (room == null) return HttpNotFound();

            // Handle User specific data if logged in
            int? userId = Session["UserID"] as int?;
            bool isAlreadyBooked = false;
            bool canReview = false;
            bool hasPendingReview = false;
            bool hasApprovedReview = false;

            if (userId != null)
            {
                // Check if user already has a pending or approved booking for THIS room
                isAlreadyBooked = db.Bookings.Any(b => b.RoomID == id && b.UserID == userId && (b.BookingStatus == "Pending" || b.BookingStatus == "Approved"));

                // Check eligibility for reviews (Must have a contract)
                bool hasStayed = db.Contracts.Any(c => 
                    c.Bookings.UserID == userId && 
                    c.Bookings.RoomID == id && 
                    (c.Status == "Active" || c.Status == "Finished"));
                
                // Get user's current reviews
                var userReviewList = db.Reviews.Where(r => r.RoomID == id && r.UserID == userId).ToList();
                
                // Rules: 
                // 1. Can only review if stayed
                // 2. Can NOT review if ANY review exists (one review per room)
                canReview = hasStayed && !userReviewList.Any();
                
                hasPendingReview = userReviewList.Any(r => r.Status == "Pending");
                hasApprovedReview = userReviewList.Any(r => r.Status == "Approved");
            }

            ViewBag.IsAlreadyBooked = isAlreadyBooked;
            ViewBag.CanReview = canReview;
            ViewBag.HasPendingReview = hasPendingReview;
            ViewBag.HasApprovedReview = hasApprovedReview;

            return View(room);
        }

        // POST: Book Room
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult BookRoom(int RoomID, DateTime CheckInDate, int? Duration, decimal? DepositAmount, string Notes)
        {
            if (Session["UserID"] == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });
            int userId = (int)Session["UserID"];

            if (Duration == null || Duration < 1)
            {
                TempData["ErrorMessage"] = "Rental duration must be at least 1 month.";
                return RedirectToAction("RoomDetails", new { id = RoomID });
            }

            if (CheckInDate < DateTime.Today)
            {
                TempData["ErrorMessage"] = "Check-in date cannot be in the past.";
                return RedirectToAction("RoomDetails", new { id = RoomID });
            }

            var room = db.Rooms.Find(RoomID);
            if (room == null || room.StatusID != 1)
            {
                TempData["ErrorMessage"] = "This room is currently not available for booking.";
                return RedirectToAction("SearchAndBook");
            }

            // Validate & set default deposit amount
            decimal finalDepositAmount;
            if (!DepositAmount.HasValue || DepositAmount.Value <= 0)
            {
                // Default: 1 month rental price
                finalDepositAmount = room.Price;
                if (finalDepositAmount <= 0)
                {
                    TempData["ErrorMessage"] = "Cannot calculate deposit amount. Please contact administrator.";
                    return RedirectToAction("RoomDetails", new { id = RoomID });
                }
            }
            else
            {
                finalDepositAmount = DepositAmount.Value;
            }

            // Fix: Prevent booking one room multiple times
            var existingBooking = db.Bookings.FirstOrDefault(b => b.RoomID == RoomID && b.UserID == userId && (b.BookingStatus == "Pending" || b.BookingStatus == "Approved"));
            if (existingBooking != null)
            {
                TempData["ErrorMessage"] = "You already have a pending booking or are currently renting this room.";
                return RedirectToAction("MyBookings");
            }

            // Create Booking
            var booking = new Bookings
            {
                RoomID = RoomID,
                UserID = userId,
                BookingStatus = "Pending",
                CheckInDate = CheckInDate,
                Duration = Duration,
                DepositAmount = finalDepositAmount,
                Notes = Notes,
                CreatedAt = DateTime.Now
            };

            db.Bookings.Add(booking);
            
            // Update Room Status to Reserved (4) immediately to prevent others from booking
            room.StatusID = 4; 
            
            // Notify Admins of new booking request
            var adminsForBooking = db.Users.Where(u => u.Role == false).ToList();
            foreach (var admin in adminsForBooking)
            {
                var notif = new Notifications
                {
                    RecipientID = admin.UserID,
                    Title = "New Booking Request",
                    Message = $"Customer {Session["FullName"]} just submitted a booking request for room P.{room.RoomNumber}.",
                    Type = "NewBooking",
                    RelatedEntityType = "Booking",
                    RelatedEntityID = booking.BookingID,
                    IsRead = false,
                    CreatedAt = DateTime.Now
                };
                db.Notifications.Add(notif);
            }

            db.SaveChanges();

            TempData["SuccessMessage"] = "Booking request submitted successfully! Please wait for admin approval.";
            return RedirectToAction("MyBookings");
        }

        // POST: Cancel Booking
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult CancelBooking(int id)
        {
            if (Session["UserID"] == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });
            int userId = (int)Session["UserID"];

            // Find the booking and include the room to reset its status
            var booking = db.Bookings.Include(b => b.Rooms).FirstOrDefault(b => b.BookingID == id && b.UserID == userId);
            
            if (booking == null)
            {
                TempData["ErrorMessage"] = "Booking request not found.";
                return RedirectToAction("MyBookings");
            }

            if (booking.BookingStatus != "Pending")
            {
                TempData["ErrorMessage"] = "Only pending booking requests can be cancelled.";
                return RedirectToAction("MyBookings");
            }

            try 
            {
                // Restore Room Status to Available (1)
                if (booking.Rooms != null)
                {
                    booking.Rooms.StatusID = 1;
                }

                db.Bookings.Remove(booking);
                db.SaveChanges();

                TempData["SuccessMessage"] = "Booking request cancelled successfully. Room is now available again.";
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = "Error cancelling booking request: " + ex.Message;
            }

            return RedirectToAction("MyBookings");
        }

        // View & Manage My Bookings
        public ActionResult MyBookings()
        {
            if (Session["UserID"] == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });
            int userId = (int)Session["UserID"];
            var bookings = db.Bookings.Include(b => b.Rooms).Where(b => b.UserID == userId).OrderByDescending(b => b.CreatedAt).ToList();
            return View(bookings);
        }


        // Request Check-out
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult RequestCheckout(int id)
        {
            try
            {
                if (Session["UserID"] == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });
                int userId = (int)Session["UserID"];

                var booking = db.Bookings.Include("Rooms").FirstOrDefault(b => b.BookingID == id && b.UserID == userId);
                if (booking == null) return HttpNotFound();

                if (booking.BookingStatus != "Approved")
                {
                    TempData["ErrorMessage"] = "Only active bookings can request check-out.";
                    return RedirectToAction("MyBookings");
                }

                // Send notification to all Admins
                var admins = db.Users.Where(u => u.Role == false).ToList();
                foreach (var admin in admins)
                {
                    var notification = new Notifications
                    {
                        RecipientID = admin.UserID,
                        SenderID = userId,
                        Title = "New Check-out Request",
                        Message = $"User {Session["FullName"]} requested check-out for room {booking.Rooms?.RoomNumber}.",
                        Type = "CheckoutRequest",
                        IsRead = false,
                        CreatedAt = DateTime.Now
                    };
                    db.Notifications.Add(notification);
                }

                db.SaveChanges();

                // Add note to booking (optional)
                booking.Notes = (string.IsNullOrEmpty(booking.Notes) ? "" : booking.Notes + "\n") + $"[User Request {DateTime.Now:dd/MM/yyyy}]: Check-out request.";
                db.SaveChanges();

                TempData["SuccessMessage"] = "Check-out request sent to Admin.";
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = "Error sending check-out request: " + ex.Message;
            }
            return RedirectToAction("MyBookings");
        }

        // View & Pay Invoices
        public ActionResult MyInvoices()
        {
            if (Session["UserID"] == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });
            int userId = (int)Session["UserID"];

            var invoices = db.Payments
                .Include(p => p.Contracts.Bookings.Rooms)
                .Where(p => p.UserID == userId)
                .OrderByDescending(p => p.DueDate)
                .ThenByDescending(p => p.CreatedAt)
                .ToList();

            return View(invoices);
        }

        // View Invoice Details (list fees)
        public ActionResult InvoiceDetails(int id)
        {
            if (Session["UserID"] == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });
            int userId = (int)Session["UserID"];

            var invoice = db.Payments
                .Include(p => p.Contracts.Bookings.Rooms)
                .Include(p => p.Fees)
                .FirstOrDefault(p => p.PaymentID == id && p.UserID == userId);

            if (invoice == null) return HttpNotFound();

            return View(invoice);
        }

        // POST: Pay Invoice (Simulated)
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult PayInvoice(int id)
        {
            if (Session["UserID"] == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });
            int userId = (int)Session["UserID"];

            var invoice = db.Payments.FirstOrDefault(p => p.PaymentID == id && p.UserID == userId);
            if (invoice == null) return HttpNotFound();

            if (invoice.PaymentStatus == "Paid")
            {
                TempData["ErrorMessage"] = "This invoice has already been paid.";
                return RedirectToAction("MyInvoices");
            }

            // Simulate payment processing
            invoice.PaymentStatus = "Paid";
            invoice.PaidDate = DateTime.Now;
            invoice.UpdatedAt = DateTime.Now;

            db.SaveChanges();

            // Create payment activity log
            var log = new ActivityLogs
            {
                UserID = userId,
                ActionType = "Pay Invoice",
                EntityType = "Payments",
                EntityID = invoice.PaymentID,
                NewValues = $"Status: Paid, Invoice: {invoice.InvoiceNumber}, Amount: {invoice.Amount}",
                CreatedAt = DateTime.Now
            };
            db.ActivityLogs.Add(log);

            // Notify Admins of payment
            var adminsForPay = db.Users.Where(u => u.Role == false).ToList();
            foreach (var admin in adminsForPay)
            {
                var notif = new Notifications
                {
                    RecipientID = admin.UserID,
                    Title = "New Invoice Payment",
                    Message = $"Invoice #{invoice.InvoiceNumber} has been paid by {Session["FullName"]}.",
                    Type = "PaymentReceived",
                    RelatedEntityType = "Payment",
                    RelatedEntityID = invoice.PaymentID,
                    IsRead = false,
                    CreatedAt = DateTime.Now
                };
                db.Notifications.Add(notif);
            }
            
            db.SaveChanges();

            return RedirectToAction("MyInvoices");
        }

        // View Notifications
        public ActionResult Notifications()
        {
            int? userId = Session["UserID"] as int?;
            if (userId == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });

            var notifications = db.Notifications
                .Where(n => n.RecipientID == userId)
                .OrderByDescending(n => n.CreatedAt)
                .ToList();

            // Update ViewBag for sidebar badge
            ViewBag.UnreadCount = notifications.Count(n => n.IsRead != true);

            return View(notifications);
        }

        // POST: Mark Notification as Read
        [HttpPost]
        public JsonResult MarkAsRead(int id)
        {
            try
            {
                var notification = db.Notifications.Find(id);
                if (notification == null) return Json(new { success = false });

                notification.IsRead = true;
                notification.ReadAt = DateTime.Now;
                db.SaveChanges();

                return Json(new { success = true });
            }
            catch
            {
                return Json(new { success = false });
            }
        }

        // POST: Clear All Notifications (mark as read)
        [HttpPost]
        public JsonResult ClearAllNotifications()
        {
            try
            {
                int? userId = Session["UserID"] as int?;
                if (userId == null) return Json(new { success = false, message = "Not logged in." });

                var unreadNotifications = db.Notifications
                    .Where(n => n.RecipientID == userId && n.IsRead != true)
                    .ToList();

                foreach (var notif in unreadNotifications)
                {
                    notif.IsRead = true;
                    notif.ReadAt = DateTime.Now;
                }

                db.SaveChanges();

                return Json(new { success = true, count = unreadNotifications.Count });
            }
            catch
            {
                return Json(new { success = false });
            }
        }

        // POST: Delete One Notification
        [HttpPost]
        public JsonResult DeleteNotification(int id)
        {
            try
            {
                var notification = db.Notifications.Find(id);
                if (notification == null) return Json(new { success = false });

                db.Notifications.Remove(notification);
                db.SaveChanges();

                return Json(new { success = true });
            }
            catch
            {
                return Json(new { success = false });
            }
        }

        // POST: Delete All Notifications Permanently
        [HttpPost]
        public JsonResult DeleteAllNotifications()
        {
            try
            {
                int? userId = Session["UserID"] as int?;
                if (userId == null) return Json(new { success = false, message = "Not logged in." });

                var notifications = db.Notifications.Where(n => n.RecipientID == userId).ToList();
                db.Notifications.RemoveRange(notifications);
                db.SaveChanges();

                return Json(new { success = true, count = notifications.Count });
            }
            catch
            {
                return Json(new { success = false });
            }
        }

        // GET: Review Rented Room
        public ActionResult ReviewRoom(int roomId)
        {
            int? userId = Session["UserID"] as int?;
            if (userId == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });

            // Check if user has an active or completed contract for this room
            var hasContract = db.Contracts.Any(c => 
                c.Bookings.UserID == userId && 
                c.Bookings.RoomID == roomId && 
                (c.Status == "Active" || c.Status == "Finished"));

            if (!hasContract)
            {
                TempData["ErrorMessage"] = "You can only review rooms you have rented or are currently renting.";
                return RedirectToAction("RoomDetails", new { id = roomId });
            }

            // Check if already reviewed
            var hasReview = db.Reviews.Any(r => r.RoomID == roomId && r.UserID == userId);
            if (hasReview)
            {
                TempData["ErrorMessage"] = "You have already submitted a review for this room.";
                return RedirectToAction("RoomDetails", new { id = roomId });
            }

            var room = db.Rooms.Find(roomId);
            ViewBag.Room = room;
            return View();
        }

        // POST: Submit Review
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult SubmitReview(int roomId, decimal rating, string comment)
        {
            int? userId = Session["UserID"] as int?;
            if (userId == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });

            // Final safety check
            var hasReview = db.Reviews.Any(r => r.RoomID == roomId && r.UserID == userId);
            if (hasReview)
            {
                TempData["ErrorMessage"] = "You have already submitted a review for this room.";
                return RedirectToAction("RoomDetails", new { id = roomId });
            }

            if (rating < 1 || rating > 5)
            {
                TempData["ErrorMessage"] = "Please select a rating from 1 to 5 stars.";
                return RedirectToAction("ReviewRoom", new { roomId = roomId });
            }

            var review = new Reviews
            {
                RoomID = roomId,
                UserID = userId.Value,
                Rating = rating,
                Comment = comment,
                Status = "Pending",
                CreatedAt = DateTime.Now,
                UpdatedAt = DateTime.Now
            };

            db.Reviews.Add(review);
            
            // Notify Admins of new review
            var roomForReview = db.Rooms.Find(roomId);
            var adminsForReview = db.Users.Where(u => u.Role == false).ToList();
            foreach (var admin in adminsForReview)
            {
                var notif = new Notifications
                {
                    RecipientID = admin.UserID,
                    Title = "New Room Review",
                    Message = $"Customer {Session["FullName"]} just submitted a review for room P.{roomForReview?.RoomNumber}.",
                    Type = "NewReview",
                    RelatedEntityType = "Review",
                    RelatedEntityID = review.ReviewID,
                    IsRead = false,
                    CreatedAt = DateTime.Now
                };
                db.Notifications.Add(notif);
            }

            db.SaveChanges();

            TempData["SuccessMessage"] = "Thank you for your review! Your comment is being moderated.";
            return RedirectToAction("RoomDetails", new { id = roomId });
        }
    }
}