class CheckoutPricing {
  static const vouchers = {'PAWPALS10', 'HUTECH10', 'FREESHIP'};
  static double discount(double subtotal, String? voucher) =>
      voucher == 'PAWPALS10' || voucher == 'HUTECH10'
      ? (subtotal * .1).roundToDouble()
      : 0;
  static double shipping(double subtotal, String? voucher) =>
      subtotal == 0 || subtotal >= 300000 || voucher == 'FREESHIP' ? 0 : 25000;
}
