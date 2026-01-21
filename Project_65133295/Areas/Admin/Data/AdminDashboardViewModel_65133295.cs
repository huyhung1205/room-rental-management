using System;
using System.Collections.Generic;

namespace Project_65133295.Areas.Admin.Data
{
    public class AdminDashboardViewModel_65133295
    {
        public decimal TotalRevenue { get; set; }
        public int TotalRooms { get; set; }
        public int OccupiedRooms { get; set; }
        public int PendingBookings { get; set; }
        public int TotalUsers { get; set; }

        public List<MonthlyRevenue_65133295> MonthlyRevenue { get; set; }
        public List<RoomStatusCount_65133295> RoomStatusBreakdown { get; set; }
        public List<RecentActivity_65133295> RecentActivities { get; set; }
    }

    public class MonthlyRevenue_65133295
    {
        public string Month { get; set; }
        public decimal Revenue { get; set; }
    }

    public class RoomStatusCount_65133295
    {
        public string StatusName { get; set; }
        public int Count { get; set; }
    }

    public class RecentActivity_65133295
    {
        public DateTime Date { get; set; }
        public string User { get; set; }
        public string Action { get; set; }
        public string Description { get; set; }
    }
}
