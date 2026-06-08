import 'package:intl/intl.dart';

/// Dropdown order: Arab/Gulf first (AED default), then South & East Asia.
const messCurrencyOrder = <String>[
  'AED',
  'SAR',
  'QAR',
  'KWD',
  'BHD',
  'OMR',
  'JOD',
  'EGP',
  'IQD',
  'LBP',
  'PKR',
  'INR',
  'BDT',
  'NPR',
  'LKR',
  'MVR',
  'AFN',
  'MYR',
  'SGD',
  'IDR',
  'THB',
  'PHP',
  'VND',
  'MMK',
  'KHR',
  'LAK',
  'CNY',
  'HKD',
  'TWD',
  'JPY',
  'KRW',
  'MNT',
  'USD',
];

const messCurrencyMeta = <String, ({String label, String symbol, String locale})>{
  'AED': (label: 'AED - UAE Dirham', symbol: 'AED ', locale: 'en_AE'),
  'SAR': (label: 'SAR - Saudi Riyal', symbol: 'SAR ', locale: 'en_SA'),
  'QAR': (label: 'QAR - Qatari Riyal', symbol: 'QAR ', locale: 'en_QA'),
  'KWD': (label: 'KWD - Kuwaiti Dinar', symbol: 'KWD ', locale: 'en_KW'),
  'BHD': (label: 'BHD - Bahraini Dinar', symbol: 'BHD ', locale: 'en_BH'),
  'OMR': (label: 'OMR - Omani Rial', symbol: 'OMR ', locale: 'en_OM'),
  'JOD': (label: 'JOD - Jordanian Dinar', symbol: 'JOD ', locale: 'en_JO'),
  'EGP': (label: 'EGP - Egyptian Pound', symbol: 'EGP ', locale: 'en_EG'),
  'IQD': (label: 'IQD - Iraqi Dinar', symbol: 'IQD ', locale: 'ar_IQ'),
  'LBP': (label: 'LBP - Lebanese Pound', symbol: 'LBP ', locale: 'ar_LB'),
  'PKR': (label: 'PKR - Pakistani Rupee', symbol: '₨', locale: 'en_PK'),
  'INR': (label: 'INR - Indian Rupee', symbol: '₹', locale: 'en_IN'),
  'BDT': (label: 'BDT - Bangladeshi Taka', symbol: '৳', locale: 'bn_BD'),
  'NPR': (label: 'NPR - Nepalese Rupee', symbol: 'NPR ', locale: 'ne_NP'),
  'LKR': (label: 'LKR - Sri Lankan Rupee', symbol: 'LKR ', locale: 'en_LK'),
  'MVR': (label: 'MVR - Maldivian Rufiyaa', symbol: 'MVR ', locale: 'en_MV'),
  'AFN': (label: 'AFN - Afghan Afghani', symbol: 'AFN ', locale: 'fa_AF'),
  'MYR': (label: 'MYR - Malaysian Ringgit', symbol: 'RM', locale: 'ms_MY'),
  'SGD': (label: 'SGD - Singapore Dollar', symbol: 'S\$', locale: 'en_SG'),
  'IDR': (label: 'IDR - Indonesian Rupiah', symbol: 'Rp', locale: 'id_ID'),
  'THB': (label: 'THB - Thai Baht', symbol: '฿', locale: 'th_TH'),
  'PHP': (label: 'PHP - Philippine Peso', symbol: '₱', locale: 'en_PH'),
  'VND': (label: 'VND - Vietnamese Dong', symbol: '₫', locale: 'vi_VN'),
  'MMK': (label: 'MMK - Myanmar Kyat', symbol: 'MMK ', locale: 'my_MM'),
  'KHR': (label: 'KHR - Cambodian Riel', symbol: 'KHR ', locale: 'km_KH'),
  'LAK': (label: 'LAK - Lao Kip', symbol: 'LAK ', locale: 'lo_LA'),
  'CNY': (label: 'CNY - Chinese Yuan', symbol: '¥', locale: 'zh_CN'),
  'HKD': (label: 'HKD - Hong Kong Dollar', symbol: 'HK\$', locale: 'zh_HK'),
  'TWD': (label: 'TWD - Taiwan Dollar', symbol: 'NT\$', locale: 'zh_TW'),
  'JPY': (label: 'JPY - Japanese Yen', symbol: '¥', locale: 'ja_JP'),
  'KRW': (label: 'KRW - South Korean Won', symbol: '₩', locale: 'ko_KR'),
  'MNT': (label: 'MNT - Mongolian Tugrik', symbol: 'MNT ', locale: 'mn_MN'),
  'USD': (label: 'USD - US Dollar', symbol: r'$', locale: 'en_US'),
};

/// Legacy alias — iteration order is not guaranteed; use [messCurrencyOrder].
Map<String, ({String label, String symbol, String locale})> get messCurrencies =>
    messCurrencyMeta;

const String defaultMessCurrency = 'AED';

String resolveMessCurrency(String? currencyCode) {
  if (currencyCode != null && messCurrencyMeta.containsKey(currencyCode)) {
    return currencyCode;
  }
  return defaultMessCurrency;
}

String formatMessMoney(double amount, {String? currencyCode}) {
  final code = resolveMessCurrency(currencyCode);
  final meta = messCurrencyMeta[code]!;
  return NumberFormat.currency(locale: meta.locale, symbol: meta.symbol).format(amount);
}
