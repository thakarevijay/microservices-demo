namespace BuildingBlocks.Domain;

/// <summary>
/// Base class for value objects. Equality is based on the components returned
/// by <see cref="GetEqualityComponents"/>, not on reference.
/// </summary>
/// <remarks>
/// Prefer <c>record</c> types for new value objects when possible — this base
/// exists for cases where you need explicit control (e.g. complex equality rules,
/// inheritance hierarchies, or mutable internal state used carefully).
/// </remarks>
public abstract class ValueObject : IEquatable<ValueObject>
{
    protected abstract IEnumerable<object?> GetEqualityComponents();

    public bool Equals(ValueObject? other) =>
        other is not null
        && GetType() == other.GetType()
        && GetEqualityComponents().SequenceEqual(other.GetEqualityComponents());

    public override bool Equals(object? obj) => obj is ValueObject vo && Equals(vo);

    public override int GetHashCode() =>
        GetEqualityComponents()
            .Aggregate(0, (current, component) =>
                HashCode.Combine(current, component?.GetHashCode() ?? 0));

    public static bool operator ==(ValueObject? left, ValueObject? right) =>
        Equals(left, right);

    public static bool operator !=(ValueObject? left, ValueObject? right) =>
        !Equals(left, right);
}
