class Lazy<T> {
  final Function f;
  T value;

  Lazy(this.f);

  T call() {
    if (value != null) {
      return value;
    } else {
      value = f();
      assert(value != null);
      return value;
    }
  }
}
