namespace BuildingBlocks.Domain.Exceptions;

/// <summary>
/// Thrown when an aggregate or entity referenced by Id does not exist.
/// Mapped to HTTP 404 by the API layer.
/// </summary>
public class NotFoundException : DomainException
{
    public NotFoundException(string entityName, object id)
        : base($"{entityName} with id '{id}' was not found.")
    {
        EntityName = entityName;
        EntityId = id;
    }

    public string EntityName { get; }

    public object EntityId { get; }
}
