using UnityEngine;

public class InteractableItem : MonoBehaviour
{
    public enum InteractionType
    {
        ToggleLight,
        SlideObject,
        PickupAndMove,
        PartnerMessage
    }

    [Header("General Interaction Settings")]
    public InteractionType interactionType = InteractionType.PickupAndMove;
    public string promptMessage = "Press [E] to grab / move";

    [Header("1. Light Settings (For ToggleLight)")]
    public Light targetLight;

    [Header("2. Slide Settings (For Window / Drawers)")]
    public Vector3 slideOffset = new Vector3(0f, 0f, -0.9f);
    public float slideSpeed = 4.0f;
    private Vector3 closedPosition;
    private Vector3 openPosition;
    private bool isOpen = false;

    [Header("3. Pickup Settings (For Furniture & Props)")]
    [Tooltip("Keep checked for large furniture (chairs, tables) so they stay level with the floor while moving.")]
    public bool keepFloorHeight = false;

    [Header("4. Message Settings (For PartnerMessage)")]
    [TextArea]
    public string partnerNote = "Don't forget we have movie night at 8 PM! <3";
    [HideInInspector]
    public bool showingMessage = false;

    void Start()
    {
        closedPosition = transform.localPosition;
        openPosition = closedPosition + slideOffset;
    }

    void Update()
    {
        // Smoothly glide the window or drawer between closed and open positions
        if (interactionType == InteractionType.SlideObject)
        {
            Vector3 targetPos = isOpen ? openPosition : closedPosition;
            transform.localPosition = Vector3.Lerp(transform.localPosition, targetPos, Time.deltaTime * slideSpeed);
        }
    }

    public void Interact()
    {
        switch (interactionType)
        {
            case InteractionType.ToggleLight:
                if (targetLight != null)
                {
                    targetLight.enabled = !targetLight.enabled;
                }
                break;

            case InteractionType.SlideObject:
                isOpen = !isOpen;
                promptMessage = isOpen ? "Press [E] to close window" : "Press [E] to open window";
                break;

            case InteractionType.PartnerMessage:
                showingMessage = !showingMessage;
                break;
        }
    }
}