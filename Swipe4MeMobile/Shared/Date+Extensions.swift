//
//  Date+Extensions.swift
//  Swipe4MeMobile
//

import Foundation

extension Date {
    var chatTimestamp: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(self) {
            // Just time: "2:30 PM"
            return formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(self) {
            // "Yesterday 2:30 PM"
            return "Yesterday " + formatted(date: .omitted, time: .shortened)
        } else if calendar.dateInterval(of: .weekOfYear, for: now)?.contains(self) == true {
            // "Monday 2:30 PM"
            return formatted(.dateTime.weekday(.wide)) + " " + formatted(date: .omitted, time: .shortened)
        } else {
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: now)
            let messageYear = calendar.component(.year, from: self)
            
            if messageYear == currentYear {
                // "Aug 15 2:30 PM"
                return formatted(.dateTime.month(.abbreviated).day(.defaultDigits)) + " " + formatted(date: .omitted, time: .shortened)
            } else {
                // "Aug 15, 2023 2:30 PM"
                return formatted(.dateTime.month(.abbreviated).day(.defaultDigits).year(.defaultDigits)) + " " + formatted(date: .omitted, time: .shortened)
            }
        }
    }
} 