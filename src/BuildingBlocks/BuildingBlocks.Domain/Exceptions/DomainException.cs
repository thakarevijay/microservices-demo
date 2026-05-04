namespace BuildingBlocks.Domain.Exceptions;

/// <summary>
/// Thrown when a domain invariant is violated.
/// Caught by the API layer's exception middleware and turned into a 4xx response.
/// </summary>
public class DomainException : Exception
{
    public DomainException(string message) : base(message)
    {
    }

    public DomainException(string message, Exception innerException) : base(message, innerException)
    {
    }
}
