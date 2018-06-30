class Lazy<T> {
  final Function f;
  T value;

  Lazy(this.f);

  T call() {
    if (value != null) {
      return value;
    } else {
      value = f() as T;
      assert(value != null);
      return value;
    }
  }
}
