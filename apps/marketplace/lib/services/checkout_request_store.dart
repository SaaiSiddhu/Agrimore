/// Private native checkout journal. Implementations must complete persistence
/// before write returns; preferences are unsuitable for financial recovery.
abstract interface class CheckoutRequestStore {
  Future<String?> read(String ownerId);
  Future<void> write(String ownerId, String value);
  Future<void> remove(String ownerId);
}
