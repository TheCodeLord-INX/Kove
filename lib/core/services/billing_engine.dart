/// Pure, stateless billing engine.
///
/// All monetary calculations live here so they can be unit-tested
/// independently of the database or UI layers.
class BillingEngine {
  BillingEngine._();

  // ── Constants ──────────────────────────────────────


  // ── Calculations ───────────────────────────────────

  /// Units consumed = current reading − previous reading.
  static double calculateUnitsConsumed(
    double prevReading,
    double currReading,
  ) {
    final diff = currReading - prevReading;
    return diff < 0 ? 0 : diff;
  }

  /// Electricity bill =
  ///   Base charge (₹150) +
  ///   IF units < threshold → units × tier1Rate
  ///   ELSE                 → units × tier2Rate
  static double calculateElectricityBill(
    double units, {
    required double tier1Rate,
    required double tier2Rate,
    required double tierThreshold,
    required double meterCharge,
  }) {
    if (units <= 0) return meterCharge;
    final variableCharge =
        units < tierThreshold ? units * tier1Rate : units * tier2Rate;
    return variableCharge > meterCharge ? variableCharge : meterCharge;
  }

  /// Total due = Rent + Electricity + Water + Adjustments + Previous Balance.
  static double calculateTotalDue({
    required double rent,
    required double electricityBill,
    required double waterBill,
    double adjustments = 0.0,
    double previousBalance = 0.0,
  }) {
    return rent + electricityBill + waterBill + adjustments + previousBalance;
  }

  /// Balance carried forward = Total Due − Amount Paid.
  static double calculateBalanceCarriedForward(
    double totalDue,
    double amountPaid,
  ) {
    return totalDue - amountPaid;
  }

  /// Convenience method that runs the full billing pipeline from raw inputs
  /// and returns a map of all computed values.
  static Map<String, double> computeFullBill({
    required double prevReading,
    required double currReading,
    required double rent,
    required double waterCharge,
    required double tier1Rate,
    required double tier2Rate,
    required double tierThreshold,
    required double meterCharge,
    double adjustments = 0.0,
    double previousBalance = 0.0,
    double amountPaid = 0.0,
  }) {
    final units = calculateUnitsConsumed(prevReading, currReading);
    final electricityBill = calculateElectricityBill(
      units,
      tier1Rate: tier1Rate,
      tier2Rate: tier2Rate,
      tierThreshold: tierThreshold,
      meterCharge: meterCharge,
    );
    final totalDue = calculateTotalDue(
      rent: rent,
      electricityBill: electricityBill,
      waterBill: waterCharge,
      adjustments: adjustments,
      previousBalance: previousBalance,
    );
    final balance = calculateBalanceCarriedForward(totalDue, amountPaid);

    return {
      'units_consumed': units,
      'electricity_bill': electricityBill,
      'water_bill': waterCharge,
      'total_due': totalDue,
      'balance_carried_forward': balance,
    };
  }

  /// Calculates the final settlement for a moving-out tenant.
  static Map<String, dynamic> calculateSettlement({
    required String moveInDateStr,
    required DateTime lastBilledDate,
    required double monthlyRent,
    required double lastReading,
    required double moveOutReading,
    required DateTime moveOutDate,
    required double tier1Rate,
    required double tier2Rate,
    required double tierThreshold,
    required double meterCharge,
  }) {
    // 1. Calculate Rent since last billing
    // We count full months first, then pro-rata days.
    
    int yearDiff = moveOutDate.year - lastBilledDate.year;
    int monthDiff = moveOutDate.month - lastBilledDate.month;
    int totalMonths = yearDiff * 12 + monthDiff;

    // Adjust if current day is before the billing day
    if (moveOutDate.day < lastBilledDate.day) {
      totalMonths--;
    }
    
    // Anniversary Recognition: If vacating on the same day as billing, it's a full month.
    // However, if totalMonths is 0 and it's the same day, we need to check if we should charge 1.
    // Example: Move in 18th, leave 18th of next month -> totalMonths should be 1.
    // Our existing logic already gives 1.
    // But if they leave on the 18th of the SAME month, it gives 0. 
    // Usually, you don't leave the day you move in, but if you leave on the exact cycle completion, 
    // it counts as 1 cycle since the last billing.
    
    // Find the latest anniversary reached
    DateTime lastAnniversaryReached = DateTime(
      lastBilledDate.year,
      lastBilledDate.month + totalMonths,
      lastBilledDate.day,
    );
    
    // Clamp day for short months
    if (lastAnniversaryReached.day != lastBilledDate.day) {
       int day = lastBilledDate.day;
       int month = lastBilledDate.month + totalMonths;
       int year = lastBilledDate.year;
       while (DateTime(year, month, day).month != (month % 12 == 0 ? 12 : month % 12)) {
         day--;
       }
       lastAnniversaryReached = DateTime(year, month, day);
    }

    final extraDays = moveOutDate.difference(lastAnniversaryReached).inDays;
    
    // Monthly Rent component (full cycles)
    final monthlyRentCharge = totalMonths * monthlyRent;
    // Pro-rata component (extra days)
    final proRataExtra = extraDays * (monthlyRent / 30);
    
    final totalRentDue = monthlyRentCharge + proRataExtra;

    // 2. Calculate Spot Electricity
    final units = calculateUnitsConsumed(lastReading, moveOutReading);
    final electricityBill = calculateElectricityBill(
      units,
      tier1Rate: tier1Rate,
      tier2Rate: tier2Rate,
      tierThreshold: tierThreshold,
      meterCharge: meterCharge,
    );

    return {
      'total_months': totalMonths,
      'extra_days': extraDays,
      'monthly_rent_charge': monthlyRentCharge,
      'pro_rata_extra': proRataExtra,
      'pro_rata_rent': totalRentDue, // Sum for compatibility
      'electricity_units': units,
      'electricity_bill': electricityBill,
      'last_anniversary': lastAnniversaryReached,
    };
  }
}
