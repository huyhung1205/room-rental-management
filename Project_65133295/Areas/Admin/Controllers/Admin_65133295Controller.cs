using System;
using System.Collections.Generic;
using System.Linq;
using System.Web.Mvc;
using System.Data.Entity;
using System.IO;
using Project_65133295.Models;
using Project_65133295.Areas.Admin.Data;
using System.Globalization;
using Project_65133295.Controllers;
using System.Web.Routing;
using System.Web.Security;

namespace Project_65133295.Areas.Admin.Controllers
{
    [CustomAuthorize(Role = "Admin")]
    public class Admin_65133295Controller : Controller
    {
        // GET: Admin/Admin_65133295

        private DbContext_65133295 db = new DbContext_65133295();

        protected override void OnActionExecuting(ActionExecutingContext filterContext)
        {
            if (Session["UserID"] != null)
            {
                int userId = Convert.ToInt32(Session["UserID"]);
                ViewBag.NotificationCount = db.Notifications.Count(n => n.RecipientID == userId && n.IsRead != true);
            }
            base.OnActionExecuting(filterContext);
        }

        [ChildActionOnly]
        public ActionResult RenderAdminNotificationBadge()
        {
            if (Session["UserID"] == null) return Content("");
            int userId = Convert.ToInt32(Session["UserID"]);
            int count = db.Notifications.Count(n => n.RecipientID == userId && n.IsRead != true);
            return PartialView("_AdminNotificationBadge", count);
        }

        // View admin notifications list
        public ActionResult Notifications()
        {
            if (Session["UserID"] == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });
            int userId = (int)Session["UserID"];

            var notifications = db.Notifications
                .Where(n => n.RecipientID == userId)
                .OrderByDescending(n => n.CreatedAt)
                .ToList();

            return View(notifications);
        }

        // POST: Mark notification as read
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
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // POST: Clear all notifications (mark all as read)
        [HttpPost]
        public JsonResult ClearAllNotifications()
        {
            try
            {
                if (Session["UserID"] == null) return Json(new { success = false, message = "Not logged in." });
                int userId = (int)Session["UserID"];

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
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // POST: Delete a notification
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
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // POST: Permanently delete all notifications
        [HttpPost]
        public JsonResult DeleteAllNotifications()
        {
            try
            {
                if (Session["UserID"] == null) return Json(new { success = false, message = "Not logged in." });
                int userId = (int)Session["UserID"];

                var notifications = db.Notifications.Where(n => n.RecipientID == userId).ToList();
                db.Notifications.RemoveRange(notifications);
                db.SaveChanges();

                return Json(new { success = true, count = notifications.Count });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // View reports (revenue, occupancy rate)
        public ActionResult Index()
        {
            var model = new AdminDashboardViewModel_65133295();

            // 1. Basic Stats
            model.TotalRevenue = db.Payments.Where(p => p.PaymentStatus == "Paid")
                                          .Select(p => (decimal?)p.Amount).Sum() ?? 0;
            model.TotalRooms = db.Rooms.Count();
            model.OccupiedRooms = db.Rooms.Count(r => r.StatusID != 1); // Assuming 1 is Available
            model.PendingBookings = db.Bookings.Count(b => b.BookingStatus == "Pending");
            model.TotalUsers = db.Users.Count(u => u.Role == true); // Assuming Role true is User

            // 2. Monthly Revenue (Last 6 months)
            var sixMonthsAgo = DateTime.Now.AddMonths(-6);
            var revenueData = db.Payments
                .Where(p => p.PaymentStatus == "Paid" && p.PaidDate >= sixMonthsAgo)
                .GroupBy(p => new { Month = p.PaidDate.Value.Month, Year = p.PaidDate.Value.Year })
                .Select(g => new { Month = g.Key.Month, Year = g.Key.Year, Total = g.Sum(p => p.Amount) })
                .ToList();

            model.MonthlyRevenue = new List<MonthlyRevenue_65133295>();
            for (int i = 5; i >= 0; i--)
            {
                var targetDate = DateTime.Now.AddMonths(-i);
                var match = revenueData.FirstOrDefault(d => d.Month == targetDate.Month && d.Year == targetDate.Year);
                model.MonthlyRevenue.Add(new MonthlyRevenue_65133295
                {
                    Month = targetDate.ToString("MM/yyyy"),
                    Revenue = match?.Total ?? 0
                });
            }

            // 3. Room Status Breakdown
            model.RoomStatusBreakdown = db.Rooms
                .GroupBy(r => r.RoomStatuses.StatusName)
                .Select(g => new RoomStatusCount_65133295
                {
                    StatusName = g.Key,
                    Count = g.Count()
                }).ToList();

            // 4. Recent Activities
            model.RecentActivities = db.ActivityLogs
                .OrderByDescending(a => a.CreatedAt)
                .Take(5)
                .Select(a => new RecentActivity_65133295
                {
                    Date = a.CreatedAt ?? DateTime.Now,
                    User = a.Users.LastName + " " + a.Users.FirstName,
                    Action = a.ActionType,
                    Description = a.Description
                }).ToList();

            ViewBag.PageTitle = "Dashboard";
            ViewBag.PageDescription = "Activity overview and revenue reports";

            return View(model);
        }

        // Manage rooms (add, edit, delete, change status, upload images, add utilities)
        public ActionResult ManageRooms()
        {
            var rooms = db.Rooms
                .Include(r => r.RoomStatuses)
                .Include(r => r.RoomImages)
                .OrderByDescending(r => r.CreatedAt)
                .ToList();

            ViewBag.PageTitle = "Manage Rooms";
            ViewBag.PageDescription = "List of all rental rooms in the system";

            return View(rooms);
        }

        // GET: Admin/Admin_65133295/CreateRoom
        public ActionResult CreateRoom()
        {
            var model = new RoomFormViewModel_65133295
            {
                Addresses = db.Addresses.ToList(),
                AddressID = db.Addresses.FirstOrDefault(a => a.Street.Contains("07 Đoàn Trần Nghiệp"))?.AddressID ?? (db.Addresses.FirstOrDefault()?.AddressID ?? 0),
                Statuses = GetTranslatedStatuses(),
                Utilities = db.Utilities.Select(u => new UtilitySelection_65133295
                {
                    UtilityID = u.UtilityID,
                    UtilityName = u.UtilityName,
                    IsSelected = false
                }).ToList(),
                PriceUnit = "VND/month",
                ExistingImages = new List<RoomImageViewModel_65133295>()
            };

            ViewBag.PageTitle = "Add New Room";
            ViewBag.PageDescription = "Fill in detailed information to add a new rental room";

            return View(model);
        }

        // POST: Admin/Admin_65133295/CreateRoom
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult CreateRoom(RoomFormViewModel_65133295 model)
        {
            if (ModelState.IsValid)
            {
                using (var transaction = db.Database.BeginTransaction())
                {
                    try
                    {
                        // Get Admin ID securely
                        int? sessionUserId = GetCurrentAdminID();
                        if (sessionUserId == null)
                        {
                            ModelState.AddModelError("", "Session expired. Please log in again.");
                            throw new Exception("Session expired");
                        }

                        // 1. Create Room
                        var room = new Rooms
                        {
                            RoomNumber = model.RoomNumber,
                            Title = model.Title,
                            Description = model.Description,
                            Area = model.Area,
                            Price = model.Price,
                            PriceUnit = model.PriceUnit ?? "VND/month",
                            AddressID = model.AddressID,
                            MaxOccupancy = model.MaxOccupancy,
                            StatusID = model.StatusID,
                            AdminID = sessionUserId.Value,
                            CreatedAt = DateTime.Now,
                            UpdatedAt = DateTime.Now
                        };
                        db.Rooms.Add(room);
                        db.SaveChanges();

                        // 2. Add Utilities
                        if (model.Utilities != null)
                        {
                            foreach (var util in model.Utilities.Where(u => u.IsSelected))
                            {
                                db.RoomUtilities.Add(new RoomUtilities
                                {
                                    RoomID = room.RoomID,
                                    UtilityID = util.UtilityID
                                });
                            }
                        }

                        // 3. Handle Image Uploads
                        if (model.NewImages != null && model.NewImages.Any())
                        {
                            string uploadDir = Server.MapPath("~/public/rooms/");
                            bool first = true;
                            
                            // Robust index calculation: find max index in current files to avoid overwrites
                            int imgIndex = 1;
                            string safeRoomNo = room.RoomNumber.Trim().Replace("/", "-").Replace("\\", "-").Replace(" ", "-");

                            foreach (var file in model.NewImages)
                            {
                                if (file != null && file.ContentLength > 0)
                                {
                                    string ext = Path.GetExtension(file.FileName);
                                    string fileName = $"{safeRoomNo}_{imgIndex}{ext}";
                                    string path = Path.Combine(uploadDir, fileName);
                                    
                                    // Security: ensures we don't overwrite if index 1 already exists somehow (e.g. manual upload)
                                    while (System.IO.File.Exists(path))
                                    {
                                        imgIndex++;
                                        fileName = $"{safeRoomNo}_{imgIndex}{ext}";
                                        path = Path.Combine(uploadDir, fileName);
                                    }

                                    file.SaveAs(path);

                                    db.RoomImages.Add(new RoomImages
                                    {
                                        RoomID = room.RoomID,
                                        ImageUrl = "/public/rooms/" + fileName,
                                        IsMainImage = first,
                                        UploadedAt = DateTime.Now,
                                        DisplayOrder = imgIndex
                                    });
                                    imgIndex++;
                                    first = false;
                                }
                            }
                        }

                        db.SaveChanges();

                        // 4. Log Activity
                        LogActivity("Create", "Rooms", room.RoomID, null, 
                            Newtonsoft.Json.JsonConvert.SerializeObject(new { room.RoomNumber, room.Title, room.Price }),
                            $"Thêm mới phòng {room.RoomNumber}");

                        transaction.Commit();
                        TempData["Message"] = "Room added successfully!";
                        return RedirectToAction("ManageRooms");
                    }
                    catch (System.Data.Entity.Validation.DbEntityValidationException ex)
                    {
                        transaction.Rollback();
                        var errorMessages = ex.EntityValidationErrors
                                .SelectMany(x => x.ValidationErrors)
                                .Select(x => x.ErrorMessage);
                        var fullErrorMessage = string.Join("; ", errorMessages);
                        ModelState.AddModelError("", "Lỗi dữ liệu: " + fullErrorMessage);
                    }
                    catch (System.Data.Entity.Infrastructure.DbUpdateException ex)
                    {
                        transaction.Rollback();
                        var innerMessage = ex.InnerException?.InnerException?.Message ?? ex.InnerException?.Message ?? ex.Message;
                        ModelState.AddModelError("", "Lỗi cập nhật CSDL: " + innerMessage);
                    }
                    catch (Exception ex)
                    {
                        transaction.Rollback();
                        ModelState.AddModelError("", "Có lỗi xảy ra: " + ex.Message);
                    }
                }
            }

            // If we got here, something failed, redisplay form
            ViewBag.PageTitle = "Thêm Phòng Mới";
            ViewBag.PageDescription = "Fill in detailed information to add a new rental room";

            model.Addresses = db.Addresses.ToList();
            model.Statuses = GetTranslatedStatuses();
            model.ExistingImages = new List<RoomImageViewModel_65133295>(); // Always safe
            
            // Sync Utilities to ensure Names are present for rendering
            var allUtils = db.Utilities.ToList();
            if (model.Utilities == null || !model.Utilities.Any())
            {
                model.Utilities = allUtils.Select(u => new UtilitySelection_65133295
                {
                    UtilityID = u.UtilityID,
                    UtilityName = u.UtilityName,
                    IsSelected = false
                }).ToList();
            }
            else
            {
                // Fill in the names for the utilities we have
                foreach (var util in model.Utilities)
                {
                    var dbUtil = allUtils.FirstOrDefault(u => u.UtilityID == util.UtilityID);
                    if (dbUtil != null) util.UtilityName = dbUtil.UtilityName;
                }
            }
            return View(model);
        }

        // GET: Admin/Admin_65133295/EditRoom/5
        public ActionResult EditRoom(int id)
        {
            var room = db.Rooms
                .Include(r => r.RoomUtilities)
                .Include(r => r.RoomImages)
                .FirstOrDefault(r => r.RoomID == id);

            if (room == null) return HttpNotFound();

            // Pull everything into memory first to avoid EF translation issues
            var selectedUtilityIds = room.RoomUtilities.Select(ru => (int)ru.UtilityID).ToList();
            var allUtilities = db.Utilities.ToList();
            var allAddresses = db.Addresses.ToList();
            var allStatuses = GetTranslatedStatuses();
            var existingImages = room.RoomImages.ToList();

            var model = new RoomFormViewModel_65133295
            {
                RoomID = room.RoomID,
                RoomNumber = room.RoomNumber,
                Title = room.Title,
                Description = room.Description,
                Area = room.Area,
                Price = room.Price,
                PriceUnit = room.PriceUnit,
                AddressID = room.AddressID,
                MaxOccupancy = room.MaxOccupancy,
                StatusID = room.StatusID,
                Addresses = allAddresses,
                Statuses = allStatuses,
                Utilities = allUtilities.Select(u => new UtilitySelection_65133295
                {
                    UtilityID = u.UtilityID,
                    UtilityName = u.UtilityName,
                    IsSelected = selectedUtilityIds.Contains(u.UtilityID)
                }).ToList(),
                ExistingImages = existingImages.Select(i => new RoomImageViewModel_65133295
                {
                    ImageID = i.ImageID,
                    ImageURL = i.ImageUrl,
                    IsPrimary = i.IsMainImage ?? false
                }).ToList()
            };

            ViewBag.PageTitle = "Chỉnh Sửa Phòng";
            ViewBag.PageDescription = "Cập nhật thông tin phòng " + room.RoomNumber;

            return View(model);
        }

        // POST: Admin/Admin_65133295/EditRoom
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult EditRoom(RoomFormViewModel_65133295 model)
        {
            if (ModelState.IsValid)
            {
                using (var transaction = db.Database.BeginTransaction())
                {
                    try
                    {
                        // Robust way to get Admin ID
                        int? sessionUserId = GetCurrentAdminID();
                        if (sessionUserId == null)
                        {
                            ModelState.AddModelError("", "Your session has expired. Please login again.");
                            throw new Exception("Session expired");
                        }

                        var room = db.Rooms
                            .Include(r => r.RoomUtilities)
                            .Include(r => r.RoomImages)
                            .FirstOrDefault(r => r.RoomID == model.RoomID);

                        if (room == null)
                        {
                            ModelState.AddModelError("", "Room not found.");
                            throw new Exception("Room not found");
                        }

                        // Store old values for logging
                        var oldValues = Newtonsoft.Json.JsonConvert.SerializeObject(new { room.Price, room.StatusID, room.Title });

                        // 1. Update Room Basic Info
                        // PER USER: Cannot change room number during edit
                        room.Title = model.Title;
                        room.Description = model.Description;
                        room.Area = model.Area;
                        room.Price = model.Price;
                        room.PriceUnit = model.PriceUnit ?? "VND/month";
                        room.AddressID = model.AddressID;
                        room.MaxOccupancy = model.MaxOccupancy;
                        room.StatusID = model.StatusID;
                        room.UpdatedAt = DateTime.Now;

                        // 2. Sync Utilities
                        var currentUtils = db.RoomUtilities.Where(ru => ru.RoomID == room.RoomID);
                        db.RoomUtilities.RemoveRange(currentUtils);
                        if (model.Utilities != null)
                        {
                            foreach (var util in model.Utilities.Where(u => u.IsSelected))
                            {
                                db.RoomUtilities.Add(new RoomUtilities { RoomID = room.RoomID, UtilityID = util.UtilityID });
                            }
                        }

                        // 3. Handle image removals
                        if (model.ExistingImages != null)
                        {
                            foreach (var img in model.ExistingImages.Where(i => i.IsDeleted))
                            {
                                var dbImg = db.RoomImages.Find(img.ImageID);
                                if (dbImg != null)
                                {
                                    // Optional: delete file from disk if you want
                                    db.RoomImages.Remove(dbImg);
                                }
                            }
                        }

                        // 4. Handle New Images
                        if (model.NewImages != null && model.NewImages.Any())
                        {
                            string uploadDir = Server.MapPath("~/public/rooms/");
                            string safeRoomNo = room.RoomNumber.Trim().Replace("/", "-").Replace("\\", "-").Replace(" ", "-");
                            
                            // Robust indexing: find the highest index currently in use for this room
                            int maxIndex = 0;
                            var currentImages = db.RoomImages.Where(ri => ri.RoomID == room.RoomID).ToList();
                            foreach (var ci in currentImages)
                            {
                                string url = ci.ImageUrl;
                                // Try to extract index from "[RoomNo]_[Index].[ext]"
                                string fileNameWithoutExt = Path.GetFileNameWithoutExtension(url);
                                string[] parts = fileNameWithoutExt.Split('_');
                                if (parts.Length > 1 && int.TryParse(parts[parts.Length - 1], out int idx))
                                {
                                    if (idx > maxIndex) maxIndex = idx;
                                }
                            }
                            
                            int imgIndex = maxIndex + 1;

                            foreach (var file in model.NewImages)
                            {
                                if (file != null && file.ContentLength > 0)
                                {
                                    string ext = Path.GetExtension(file.FileName);
                                    string fileName = $"{safeRoomNo}_{imgIndex}{ext}";
                                    string path = Path.Combine(uploadDir, fileName);
                                    
                                    // Extra safety check
                                    while (System.IO.File.Exists(path))
                                    {
                                        imgIndex++;
                                        fileName = $"{safeRoomNo}_{imgIndex}{ext}";
                                        path = Path.Combine(uploadDir, fileName);
                                    }

                                    file.SaveAs(path);

                                    db.RoomImages.Add(new RoomImages
                                    {
                                        RoomID = room.RoomID,
                                        ImageUrl = "/public/rooms/" + fileName,
                                        IsMainImage = false,
                                        UploadedAt = DateTime.Now,
                                        DisplayOrder = imgIndex
                                    });
                                    imgIndex++;
                                }
                            }
                        }

                        db.SaveChanges();

                        LogActivity("Update", "Rooms", room.RoomID, oldValues,
                            Newtonsoft.Json.JsonConvert.SerializeObject(new { room.Price, room.StatusID, room.Title }),
                            $"Updated room information {room.RoomNumber}");

                        transaction.Commit();
                        TempData["Message"] = "Update successful!";
                        return RedirectToAction("ManageRooms");
                    }
                    catch (System.Data.Entity.Validation.DbEntityValidationException ex)
                    {
                        transaction.Rollback();
                        var errorMessages = ex.EntityValidationErrors
                                .SelectMany(x => x.ValidationErrors)
                                .Select(x => x.ErrorMessage);
                        var fullErrorMessage = string.Join("; ", errorMessages);
                        ModelState.AddModelError("", "Lỗi dữ liệu: " + fullErrorMessage);
                    }
                    catch (System.Data.Entity.Infrastructure.DbUpdateException ex)
                    {
                        transaction.Rollback();
                        var innerMessage = ex.InnerException?.InnerException?.Message ?? ex.InnerException?.Message ?? ex.Message;
                        ModelState.AddModelError("", "Lỗi cập nhật CSDL: " + innerMessage);
                    }
                    catch (Exception ex)
                    {
                        transaction.Rollback();
                        ModelState.AddModelError("", "Có lỗi xảy ra: " + ex.Message);
                    }
                }
            }

            // If we got here, something failed (ModelState invalid or Exception)
            model.Addresses = db.Addresses.ToList();
            model.Statuses = GetTranslatedStatuses();
            
            // Sync Utilities to ensure Names are present for rendering
            var allUtilsForEdit = db.Utilities.ToList();
            if (model.Utilities == null || !model.Utilities.Any())
            {
                model.Utilities = allUtilsForEdit.Select(u => new UtilitySelection_65133295
                {
                    UtilityID = u.UtilityID,
                    UtilityName = u.UtilityName,
                    IsSelected = false
                }).ToList();
            }
            else
            {
                foreach (var util in model.Utilities)
                {
                    var dbUtil = allUtilsForEdit.FirstOrDefault(u => u.UtilityID == util.UtilityID);
                    if (dbUtil != null) util.UtilityName = dbUtil.UtilityName;
                }
            }
 
            // Repopulate existing images from DB
            var imagesFromDb = db.RoomImages.Where(ri => ri.RoomID == model.RoomID).ToList();
            model.ExistingImages = imagesFromDb.Select(i => new RoomImageViewModel_65133295
            {
                ImageID = i.ImageID,
                ImageURL = i.ImageUrl,
                IsPrimary = i.IsMainImage ?? false
            }).ToList();

            return View(model);
        }

        // POST: Admin/Admin_65133295/UpdateRoomStatus
        [HttpPost]
        [ValidateAntiForgeryToken]
        public JsonResult UpdateRoomStatus(int id, int statusId)
        {
            try
            {
                var room = db.Rooms.Find(id);
                if (room == null) return Json(new { success = false, message = "Không tìm thấy phòng" });

                var oldStatus = room.RoomStatuses?.StatusName;
                room.StatusID = statusId;
                room.UpdatedAt = DateTime.Now;
                db.SaveChanges();

                var newStatus = db.RoomStatuses.Find(statusId)?.StatusName;
                LogActivity("Update", "Rooms", id, oldStatus, newStatus, $"Changed room {room.RoomNumber} status to {newStatus}");

                return Json(new { success = true });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // POST: Admin/Admin_65133295/DeleteRoom
        [HttpPost]
        [ValidateAntiForgeryToken]
        public JsonResult DeleteRoom(int id)
        {
            try
            {
                var room = db.Rooms.Find(id);
                if (room == null) return Json(new { success = false, message = "Không tìm thấy phòng" });

                // Check for active bookings
                if (db.Bookings.Any(b => b.RoomID == id && (b.BookingStatus == "Pending" || b.BookingStatus == "Confirmed")))
                {
                    return Json(new { success = false, message = "Room has active bookings, cannot delete." });
                }

                // Delete related data
                db.RoomUtilities.RemoveRange(db.RoomUtilities.Where(ru => ru.RoomID == id));
                db.RoomImages.RemoveRange(db.RoomImages.Where(ri => ri.RoomID == id));
                
                db.Rooms.Remove(room);
                db.SaveChanges();

                LogActivity("Delete", "Rooms", id, room.RoomNumber, null, $"Xóa phòng {room.RoomNumber} khỏi hệ thống");

                return Json(new { success = true });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        private void LogActivity(string action, string entity, int? entityId, string oldValues, string newValues, string description)
        {
            var log = new ActivityLogs
            {
                UserID = GetCurrentAdminID(),
                ActionType = action,
                EntityType = entity,
                EntityID = entityId,
                OldValues = oldValues,
                NewValues = newValues,
                Description = description,
                IPAddress = Request.UserHostAddress,
                CreatedAt = DateTime.Now
            };
            db.ActivityLogs.Add(log);
            db.SaveChanges();
        }

        // Get current Admin ID securely, repopulating session if lost
        private int? GetCurrentAdminID()
        {
            if (Session["UserID"] != null) return Session["UserID"] as int?;

            if (User.Identity.IsAuthenticated)
            {
                string email = User.Identity.Name;
                var user = db.Users.FirstOrDefault(u => u.Email == email);
                if (user != null)
                {
                    // Re-populate session
                    Session["UserID"] = user.UserID;
                    Session["UserEmail"] = user.Email;
                    Session["UserRole"] = (user.Role == false) ? "Admin" : "User";
                    Session["FullName"] = $"{user.FirstName} {user.LastName}".Trim();
                    return user.UserID;
                }
            }
            return null;
        }

        // Quản lý booking (xem, duyệt, từ chối)
        public ActionResult ManageBookings(string query, string status)
        {
            var bookings = db.Bookings
                .Include("Rooms")
                .Include("Users1") // Users1 is the Tenant relationship (per DbContext mapping)
                .AsQueryable();

            // Filter
            if (!string.IsNullOrEmpty(query))
            {
                string term = query.Trim().ToLower();
                bookings = bookings.Where(b => (b.Users1 != null && b.Users1.FirstName.ToLower().Contains(term)) || 
                                              (b.Users1 != null && b.Users1.LastName.ToLower().Contains(term)) || 
                                              (b.Rooms != null && b.Rooms.RoomNumber.ToLower().Contains(term)));
            }

            if (!string.IsNullOrEmpty(status))
            {
                bookings = bookings.Where(b => b.BookingStatus == status);
            }

            var model = bookings.OrderByDescending(b => b.CreatedAt).ToList();
            ViewBag.CurrentQuery = query;
            ViewBag.CurrentStatus = status;

            return View(model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult ApproveBooking(int id)
        {
            using (var transaction = db.Database.BeginTransaction())
            {
                try
                {
                    // Check Session first
                    if (Session["UserID"] == null || !int.TryParse(Session["UserID"].ToString(), out int adminId))
                    {
                        TempData["ErrorMessage"] = "Session expired. Please log in again.";
                        return RedirectToAction("ManageBookings");
                    }

                    var booking = db.Bookings
                        .Include("Rooms")
                        .Include("Users1")
                        .FirstOrDefault(b => b.BookingID == id);
                    if (booking == null) return HttpNotFound();

                    if (booking.BookingStatus != "Pending")
                    {
                        TempData["ErrorMessage"] = "This request is not in pending status.";
                        return RedirectToAction("ManageBookings");
                    }

                    // Get deposit amount (should always be > 0 now)
                    decimal depositAmount = booking.DepositAmount ?? 0;
                    if (depositAmount <= 0)
                    {
                        // This shouldn't happen, but as a safety check
                        depositAmount = booking.Rooms.Price; // Use room price as fallback
                    }

                    // 1. Update Booking
                    booking.BookingStatus = "Approved";
                    booking.ApprovedAt = DateTime.Now;
                    booking.ApprovedBy = adminId;
                    db.SaveChanges(); // Save booking first

                    // 2. Create Contract
                    var contract = new Contracts
                    {
                        BookingID = booking.BookingID,
                        ContractNumber = "HD-" + DateTime.Now.Ticks.ToString().Substring(10),
                        StartDate = booking.CheckInDate,
                        EndDate = booking.CheckInDate.AddMonths(booking.Duration ?? 12),
                        RentalPrice = booking.Rooms.Price,
                        DepositAmount = depositAmount,
                        Status = "Active",
                        CreatedAt = DateTime.Now
                    };
                    db.Contracts.Add(contract);
                    db.SaveChanges(); // Save contract FIRST to get ContractID

                    // 3. Update Room
                    var room = booking.Rooms;
                    room.StatusID = 2; // Rented
                    room.CurrentTenantID = booking.UserID;
                    db.SaveChanges(); // Save room

                    // 4. Activity Log
                    var log = new ActivityLogs
                    {
                        UserID = adminId,
                        ActionType = "Approve Booking",
                        EntityType = "Bookings",
                        EntityID = booking.BookingID,
                        NewValues = $"Status: Approved, Contract: {contract.ContractNumber}, Room: {room.RoomNumber}",
                        CreatedAt = DateTime.Now
                    };
                    db.ActivityLogs.Add(log);

                    // 5. Create Initial Deposit Invoice (Payment)
                    var depositInvoice = new Payments
                    {
                        ContractID = contract.ContractID, // Now ContractID is properly set
                        UserID = booking.UserID,
                        AdminID = adminId,
                        InvoiceNumber = "INV-DEP-" + DateTime.Now.Ticks.ToString().Substring(10),
                        PaymentDate = DateTime.Now,
                        Amount = depositAmount,
                        PaymentStatus = "Pending",
                        DueDate = DateTime.Now.AddDays(3),
                        Notes = "Deposit invoice for room " + room.RoomNumber,
                        CreatedAt = DateTime.Now,
                        UpdatedAt = DateTime.Now
                    };
                    db.Payments.Add(depositInvoice);
                    db.SaveChanges(); // Save payment to get PaymentID

                    // 6. Notification for User
                    var notification = new Notifications
                    {
                        RecipientID = booking.UserID,
                        SenderID = adminId,
                        Title = "Booking request APPROVED",
                        Message = $"Hello {booking.Users1.FirstName}, your booking request for room {room.RoomNumber} has been approved. Please pay the deposit invoice of {depositInvoice.Amount.ToString("N0")} VND in the 'My Invoices' section to complete the check-in!",
                        Type = "Success",
                        RelatedEntityType = "Payments",
                        RelatedEntityID = depositInvoice.PaymentID, // Now PaymentID is properly set
                        IsRead = false,
                        CreatedAt = DateTime.Now
                    };
                    db.Notifications.Add(notification);
                    db.SaveChanges(); // Final save for notification

                    transaction.Commit();

                    TempData["SuccessMessage"] = $"Approved booking request from {(booking.Users1 != null ? booking.Users1.LastName : "Guest")} and created contract {contract.ContractNumber} successfully!";
                }
                catch (Exception ex)
                {
                    transaction.Rollback();
                    TempData["ErrorMessage"] = "Error approving booking: " + ex.Message;
                }
            }
            return RedirectToAction("ManageBookings");
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult RejectBooking(int id, string reason)
        {
            try
            {
                var booking = db.Bookings
                    .Include("Rooms")
                    .Include("Users1")
                    .FirstOrDefault(b => b.BookingID == id);
                if (booking == null) return HttpNotFound();

                if (booking.BookingStatus != "Pending")
                {
                    TempData["ErrorMessage"] = "This request is not in pending status.";
                    return RedirectToAction("ManageBookings");
                }

                // 1. Update Booking
                booking.BookingStatus = "Rejected";
                booking.Notes = (booking.Notes ?? "") + "\n[Rejection Reason]: " + reason;

                // 2. Notification for User
                var notification = new Notifications
                {
                    RecipientID = booking.UserID,
                    SenderID = (int)Session["UserID"],
                    Title = "Booking request REJECTED",
                    Message = $"Hello {booking.Users1.FirstName}, unfortunately your booking request for room {booking.Rooms.RoomNumber} has been rejected. Reason: {reason}",
                    Type = "Error",
                    RelatedEntityType = "Bookings",
                    RelatedEntityID = booking.BookingID,
                    IsRead = false,
                    CreatedAt = DateTime.Now
                };
                db.Notifications.Add(notification);

                // 3. Reset Room Status if it was Reserved (4)
                var room = booking.Rooms;
                if (room.StatusID == 4) // Reserved
                {
                    // Check if there are other pending bookings for this room
                    bool hasOtherPending = db.Bookings.Any(b => b.RoomID == room.RoomID && b.BookingStatus == "Pending" && b.BookingID != id);
                    if (!hasOtherPending)
                    {
                        room.StatusID = 1; // Available
                    }
                }

                // 3. Activity Log
                var log = new ActivityLogs
                {
                    UserID = (int)Session["UserID"],
                    ActionType = "Reject Booking",
                    EntityType = "Bookings",
                    EntityID = booking.BookingID,
                    NewValues = $"Status: Rejected, Reason: {reason}",
                    CreatedAt = DateTime.Now
                };
                db.ActivityLogs.Add(log);

                db.SaveChanges();
                TempData["SuccessMessage"] = "Booking request rejected successfully.";
            }
            catch (Exception ex)
            {
                TempData["ErrorMessage"] = "Error rejecting booking: " + ex.Message;
            }
            return RedirectToAction("ManageBookings");
        }

        // Manage contracts
        public ActionResult ManageContracts(string query, string status)
        {
            var contracts = db.Contracts
                .Include("Bookings.Rooms")
                .Include("Bookings.Users1") // Tenant
                .AsQueryable();

            if (!string.IsNullOrEmpty(query))
            {
                string term = query.Trim().ToLower();
                contracts = contracts.Where(c => c.ContractNumber.ToLower().Contains(term) ||
                                                (c.Bookings != null && c.Bookings.Users1 != null && c.Bookings.Users1.FirstName.ToLower().Contains(term)) ||
                                                (c.Bookings != null && c.Bookings.Users1 != null && c.Bookings.Users1.LastName.ToLower().Contains(term)) ||
                                                (c.Bookings != null && c.Bookings.Rooms != null && c.Bookings.Rooms.RoomNumber.ToLower().Contains(term)));
            }

            if (!string.IsNullOrEmpty(status))
            {
                contracts = contracts.Where(c => c.Status == status);
            }

            var model = contracts.OrderByDescending(c => c.CreatedAt).ToList();
            ViewBag.CurrentQuery = query;
            ViewBag.CurrentStatus = status;
            return View(model);
        }

        // Manage invoices (list of invoices)
        public ActionResult CreateMonthlyInvoices(string query, string status)
        {
            var payments = db.Payments
                .Include("Contracts.Bookings.Rooms")
                .Include("Users1") // Tenant
                .AsQueryable();

            if (!string.IsNullOrEmpty(query))
            {
                string term = query.Trim().ToLower();
                payments = payments.Where(p => p.InvoiceNumber.ToLower().Contains(term) ||
                                              (p.Users1 != null && p.Users1.FirstName.ToLower().Contains(term)) ||
                                              (p.Users1 != null && p.Users1.LastName.ToLower().Contains(term)) ||
                                              (p.Contracts != null && p.Contracts.Bookings != null && p.Contracts.Bookings.Rooms != null && p.Contracts.Bookings.Rooms.RoomNumber.ToLower().Contains(term)));
            }

            if (!string.IsNullOrEmpty(status))
            {
                payments = payments.Where(p => p.PaymentStatus == status);
            }

            var model = payments.OrderByDescending(p => p.CreatedAt).ToList();
            ViewBag.CurrentQuery = query;
            ViewBag.CurrentStatus = status;
            return View(model);
        }

        [HttpGet]
        public ActionResult CreateInvoice(int? contractId)
        {
            if (contractId == null) return RedirectToAction("ManageContracts");
            var contract = db.Contracts
                .Include("Bookings.Rooms")
                .Include("Bookings.Users1")
                .FirstOrDefault(c => c.ContractID == contractId);
            
            if (contract == null) return HttpNotFound();
            
            return View(contract);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult CreateInvoice(int ContractID, DateTime PaymentDate, DateTime DueDate, string Notes, string[] FeeName, decimal[] FeeAmount)
        {
            var contract = db.Contracts.Include("Bookings").FirstOrDefault(c => c.ContractID == ContractID);
            if (contract == null) return HttpNotFound();

            using (var transaction = db.Database.BeginTransaction())
            {
                try
                {
                    var payment = new Payments
                    {
                        ContractID = ContractID,
                        UserID = contract.Bookings.UserID,
                        AdminID = (int)Session["UserID"],
                        InvoiceNumber = "INV-" + DateTime.Now.Ticks.ToString().Substring(10),
                        PaymentDate = PaymentDate,
                        DueDate = DueDate,
                        PaymentStatus = "Pending",
                        Notes = Notes,
                        CreatedAt = DateTime.Now,
                        Amount = contract.RentalPrice // Base amount
                    };

                    db.Payments.Add(payment);
                    db.SaveChanges(); // Get PaymentID

                    decimal totalFees = 0;
                    if (FeeName != null)
                    {
                        for (int i = 0; i < FeeName.Length; i++)
                        {
                            if (!string.IsNullOrEmpty(FeeName[i]))
                            {
                                var fee = new Fees
                                {
                                    PaymentID = payment.PaymentID,
                                    FeeName = FeeName[i],
                                    FeeAmount = FeeAmount[i]
                                };
                                db.Fees.Add(fee);
                                totalFees += FeeAmount[i];
                            }
                        }
                    }

                    payment.Amount += totalFees;
                    db.SaveChanges();

                    // Notification
                    var notification = new Notifications
                    {
                        RecipientID = payment.UserID,
                        SenderID = payment.AdminID,
                        Title = "New invoice for month " + PaymentDate.Month,
                        Message = $"You have a new invoice {payment.InvoiceNumber} for {payment.Amount:N0} VND. Please pay before {DueDate:dd/MM}.",
                        Type = "Invoice",
                        RelatedEntityType = "Payments",
                        RelatedEntityID = payment.PaymentID,
                        IsRead = false,
                        CreatedAt = DateTime.Now
                    };
                    db.Notifications.Add(notification);

                    db.SaveChanges();
                    transaction.Commit();
                    TempData["SuccessMessage"] = "Invoice created successfully!";
                    return RedirectToAction("CreateMonthlyInvoices");
                }
                catch (Exception ex)
                {
                    transaction.Rollback();
                    TempData["ErrorMessage"] = "Error creating invoice: " + ex.Message;
                    return RedirectToAction("CreateInvoice", new { contractId = ContractID });
                }
            }
        }

        // POST: Handle room checkout
        [HttpPost]
        [ValidateAntiForgeryToken]
        public ActionResult CheckoutContract(int id)
        {
            using (var transaction = db.Database.BeginTransaction())
            {
                try
                {
                    if (Session["UserID"] == null) return RedirectToAction("Login", "Guest_65133295", new { area = "" });

                    var contract = db.Contracts
                        .Include("Bookings.Rooms")
                        .Include("Bookings.Users1")
                        .FirstOrDefault(c => c.ContractID == id);

                    if (contract == null) return HttpNotFound();

                    if (contract.Status != "Active")
                    {
                        TempData["ErrorMessage"] = "This contract is not active for checkout.";
                        return RedirectToAction("ManageContracts");
                    }

                    // 1. Update contract status
                    contract.Status = "Terminated";
                    contract.UpdatedAt = DateTime.Now;

                    // 2. Update room status (Available)
                    var room = contract.Bookings?.Rooms;
                    if (room != null)
                    {
                        room.StatusID = 1; // Available
                        room.CurrentTenantID = null;
                        room.UpdatedAt = DateTime.Now;
                    }

                    // 3. Update booking status (Completed)
                    if (contract.Bookings != null)
                    {
                        contract.Bookings.BookingStatus = "Completed";
                        contract.Bookings.UpdatedAt = DateTime.Now;
                    }

                    // 4. Log activity
                    var log = new ActivityLogs
                    {
                        UserID = (int)Session["UserID"],
                        ActionType = "Checkout",
                        EntityType = "Contracts",
                        EntityID = contract.ContractID,
                        NewValues = $"Status: Terminated, Room {(room != null ? room.RoomNumber : "N/A")} is now available",
                        CreatedAt = DateTime.Now
                    };
                    db.ActivityLogs.Add(log);

                    // 5. Send notification to User (Tenant)
                    if (contract.Bookings?.Users1 != null)
                    {
                        var notification = new Notifications
                        {
                            RecipientID = contract.Bookings.UserID,
                            SenderID = (int)Session["UserID"],
                            Title = "Checkout completed",
                            Message = $"Your checkout process for room {(room != null ? room.RoomNumber : "N/A")} has been completed. Thank you!",
                            Type = "CheckoutCompleted",
                            IsRead = false,
                            CreatedAt = DateTime.Now
                        };
                        db.Notifications.Add(notification);
                    }

                    db.SaveChanges();
                    transaction.Commit();

                    TempData["SuccessMessage"] = $"Room {(room != null ? room.RoomNumber : "N/A")} has been released.";
                }
                catch (Exception ex)
                {
                    transaction.Rollback();
                    string fullError = ex.Message;
                    Exception inner = ex.InnerException;
                    while (inner != null)
                    {
                        fullError += " -> " + inner.Message;
                        inner = inner.InnerException;
                    }
                    TempData["ErrorMessage"] = "Error processing checkout: " + fullError;
                }
            }
            return RedirectToAction("ManageContracts");
        }

        // Manage users (lock/unlock)
        public ActionResult ManageUsers(string query = "", int page = 1, bool? role = null)
        {
            const int USERS_PER_PAGE = 5; // Configurable: users per page

            // Start with all users
            var usersQuery = db.Users.AsQueryable();

            // Filter by Role if provided
            if (role.HasValue)
            {
                usersQuery = usersQuery.Where(u => u.Role == role.Value);
            }

            // Search functionality
            if (!string.IsNullOrEmpty(query))
            {
                string searchTerm = query.Trim().ToLower();
                usersQuery = usersQuery.Where(u =>
                    u.Email.ToLower().Contains(searchTerm) ||
                    (u.FirstName != null && u.FirstName.ToLower().Contains(searchTerm)) ||
                    (u.LastName != null && u.LastName.ToLower().Contains(searchTerm)) ||
                    (u.PhoneNumber != null && u.PhoneNumber.Contains(searchTerm))
                );
            }

            // Calculate pagination
            int totalUsers = usersQuery.Count();
            int totalPages = (int)Math.Ceiling((double)totalUsers / USERS_PER_PAGE);
            page = Math.Max(1, Math.Min(page, totalPages)); // Clamp page number

            // Handle empty page case
            if (totalUsers == 0) page = 1;

            var users = usersQuery
                .OrderByDescending(u => u.CreatedAt)
                .Skip((page - 1) * USERS_PER_PAGE)
                .Take(USERS_PER_PAGE)
                .ToList();

            // Pass data to view
            ViewBag.Query = query;
            ViewBag.Page = page;
            ViewBag.TotalPages = totalPages;
            ViewBag.TotalUsers = totalUsers;
            ViewBag.CurrentRole = role; // Pass current filter back to view

            return View(users);
        }

        // POST: Delete User
        [HttpPost]
        [ValidateAntiForgeryToken]
        public JsonResult DeleteUser(int id)
        {
            try
            {
                var user = db.Users.Find(id);
                if (user == null) return Json(new { success = false, message = "User not found" });

                // Prevent deleting Admins (Role = false)
                if (user.Role == false)
                {
                    return Json(new { success = false, message = "Cannot delete admin account!" });
                }

                // Delete dependencies
                db.Users.Remove(user);
                db.SaveChanges();

                LogActivity("Delete", "Users", id, user.Email, null, $"Deleted user {user.Email}");

                return Json(new { success = true });
            }
            catch (Exception ex)
            {
                // Inner exception usually contains FK constraint info
                string msg = ex.InnerException != null ? ex.InnerException.Message : ex.Message;
                return Json(new { success = false, message = "Cannot delete: this user has related data (Bookings, Reviews, etc.)." });
            }
        }

        // POST: Toggle User Lock/Unlock
        [HttpPost]
        [ValidateAntiForgeryToken]
        public JsonResult ToggleUserLock(int userId, string reason)
        {
            try
            {
                // Validate reason
                if (string.IsNullOrWhiteSpace(reason))
                {
                    return Json(new { success = false, message = "Please provide a reason for lock/unlock." });
                }

                var user = db.Users.Find(userId);
                if (user == null)
                {
                    return Json(new { success = false, message = "User not found." });
                }

                // Prevent locking admin accounts (Role=false means Admin)
                if (user.Role == false)
                {
                    return Json(new { success = false, message = "Cannot lock admin account." });
                }

                // Get current admin ID
                int? adminId = GetCurrentAdminID();
                if (adminId == null)
                {
                    return Json(new { success = false, message = "Session expired." });
                }

                // Toggle IsActive
                bool oldStatus = user.IsActive ?? true;
                user.IsActive = !oldStatus;
                bool newStatus = user.IsActive ?? false;

                db.SaveChanges();

                // Log activity
                string action = newStatus ? "Unlocked" : "Locked";
                LogActivity("Update", "Users", userId,
                    Newtonsoft.Json.JsonConvert.SerializeObject(new { IsActive = oldStatus }),
                    Newtonsoft.Json.JsonConvert.SerializeObject(new { IsActive = newStatus }),
                    $"{action} account {user.Email}. Reason: {reason}");

                string message = newStatus ? 
                    $"Account {user.Email} unlocked" : 
                    $"Account {user.Email} locked";

                return Json(new { success = true, message = message });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = "Error: " + ex.Message });
            }
        }

        // View invoice details
        public ActionResult InvoiceDetails(int id)
        {
            var invoice = db.Payments
                .Include(p => p.Contracts.Bookings.Rooms)
                .Include(p => p.Users1)
                .Include(p => p.Fees)
                .FirstOrDefault(p => p.PaymentID == id);

            if (invoice == null) return HttpNotFound();

            ViewBag.PageTitle = "Invoice Details";
            ViewBag.PageDescription = "Detailed invoice information and fee breakdown for invoice #" + invoice.InvoiceNumber;

            return View(invoice);
        }

        // Approve reviews
        public ActionResult ApproveReviews()
        {
            var pendingReviews = db.Reviews
                .Include(r => r.Rooms)
                .Include(r => r.Users)
                .Where(r => r.Status == "Pending")
                .OrderByDescending(r => r.CreatedAt)
                .ToList();

            return View(pendingReviews);
        }

        // POST: Update review status
        [HttpPost]
        [ValidateAntiForgeryToken]
        public JsonResult UpdateReviewStatus(int id, string status)
        {
            try
            {
                var review = db.Reviews.Find(id);
                if (review == null) return Json(new { success = false, message = "Review not found." });

                review.Status = status;
                review.UpdatedAt = DateTime.Now;
                db.SaveChanges();

                // Notify User about review status update
                var userNotification = new Notifications
                {
                    RecipientID = review.UserID,
                    Title = status == "Approved" ? "Review Approved" : "Review Rejected",
                    Message = status == "Approved" 
                        ? $"Your review for room P.{review.Rooms?.RoomNumber} has been approved and is now visible." 
                        : $"Unfortunately, your review for room P.{review.Rooms?.RoomNumber} was not approved due to policy violation.",
                    Type = status == "Approved" ? "Approval" : "Rejection",
                    RelatedEntityType = "Review",
                    RelatedEntityID = review.ReviewID,
                    IsRead = false,
                    CreatedAt = DateTime.Now
                };
                db.Notifications.Add(userNotification);
                db.SaveChanges();

                string actionText = status == "Approved" ? "Approved" : "Rejected";
                LogActivity("Update", "Reviews", id, null, status, $"{actionText} review from {review.Users?.Email} for room {review.Rooms?.RoomNumber}");

                return Json(new { success = true });
            }
            catch (Exception ex)
            {
                return Json(new { success = false, message = ex.Message });
            }
        }

        // View activity history
        public ActionResult ViewActivityLogs(string query = "", string fromDate = "", string toDate = "", string actionType = "", int page = 1)
        {
            const int LOGS_PER_PAGE = 20;

            var logsQuery = db.ActivityLogs.Include("Users").AsQueryable();

            // Filter by date range
            if (DateTime.TryParse(fromDate, out DateTime start))
            {
                logsQuery = logsQuery.Where(l => l.CreatedAt >= start);
            }
            if (DateTime.TryParse(toDate, out DateTime end))
            {
                // Include the end date fully (up to 23:59:59)
                end = end.Date.AddDays(1).AddTicks(-1);
                logsQuery = logsQuery.Where(l => l.CreatedAt <= end);
            }

            // Filter by ActionType
            if (!string.IsNullOrEmpty(actionType))
            {
                logsQuery = logsQuery.Where(l => l.ActionType == actionType);
            }

            // Search by Description or Entity
            if (!string.IsNullOrEmpty(query))
            {
                string lowerQuery = query.ToLower();
                logsQuery = logsQuery.Where(l => 
                    l.Description.ToLower().Contains(lowerQuery) || 
                    l.EntityType.ToLower().Contains(lowerQuery) ||
                    (l.Users != null && l.Users.Email.Contains(lowerQuery))
                );
            }

            // Get all logs sorted by date
            var logs = logsQuery
                .OrderByDescending(l => l.CreatedAt)
                .ToList();

            // Pass data to view
            ViewBag.Query = query;
            ViewBag.FromDate = fromDate;
            ViewBag.ToDate = toDate;
            ViewBag.ActionType = actionType;
            ViewBag.TotalLogs = logs.Count;

            // Get distinct ActionTypes for dropdown
            ViewBag.ActionTypes = db.ActivityLogs.Select(l => l.ActionType).Distinct().ToList();

            return View(logs);
        }
        // Helper to get translated statuses
        private List<RoomStatuses> GetTranslatedStatuses()
        {
            return db.RoomStatuses.AsEnumerable().Select(s => {
                string name = (s.StatusName ?? "").Trim();
                string translatedName = s.StatusName;

                if (s.StatusID == 1 || name.Equals("Available", StringComparison.OrdinalIgnoreCase))
                    translatedName = "Available";
                else if (s.StatusID == 2 || name.Equals("Rented", StringComparison.OrdinalIgnoreCase))
                    translatedName = "Rented";
                else if (s.StatusID == 3 || name.Equals("Maintenance", StringComparison.OrdinalIgnoreCase))
                    translatedName = "Maintenance";
                else if (s.StatusID == 4 || name.Equals("Reserved", StringComparison.OrdinalIgnoreCase))
                    translatedName = "Reserved";

                return new RoomStatuses
                {
                    StatusID = s.StatusID,
                    StatusName = translatedName
                };
            }).ToList();
        }
    }
}