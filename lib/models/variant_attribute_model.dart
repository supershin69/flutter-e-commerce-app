class VariantAttribute {
  final String type; // 'color', 'ram'
  final String value; // 'red', '8gb'
  final String displayValue; // 'Red', '8GB'
  final String attributeValueId; // UUID needed for matching images

  VariantAttribute({
    required this.type,
    required this.value,
    required this.displayValue,
    required this.attributeValueId,
  });

  factory VariantAttribute.fromMap(Map<String, dynamic> map) {
    return VariantAttribute(
      type: map['type'],
      value: map['value'],
      displayValue: map['display_value'] ?? map['value'],
      attributeValueId: map['attribute_value_id'],
    );
  }
}