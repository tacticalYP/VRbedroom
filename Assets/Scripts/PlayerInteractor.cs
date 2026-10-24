using UnityEngine;
using TMPro;

public class PlayerInteractor : MonoBehaviour
{
    public float interactRange = 3.5f;
    public float moveSmoothSpeed = 12.0f;
    public TMP_Text promptUI;

    private InteractableItem heldItem = null;
    private float holdDistance = 2.0f;
    private float originalY = 0f;
    private Collider[] heldColliders;

    void Update()
    {
        // If we are currently holding an object, move it with our view
        if (heldItem != null)
        {
            HandleHeldObject();
            return;
        }

        // Otherwise, raycast forward to detect interactable items
        Ray ray = new Ray(transform.position, transform.forward);
        RaycastHit hit;

        if (Physics.Raycast(ray, out hit, interactRange))
        {
            InteractableItem item = hit.collider.GetComponentInParent<InteractableItem>();

            if (item != null)
            {
                if (item.interactionType == InteractableItem.InteractionType.PartnerMessage && item.showingMessage)
                {
                    promptUI.text = item.partnerNote + "\n(Press [E] to close)";
                }
                else
                {
                    promptUI.text = item.promptMessage;
                }

                if (Input.GetKeyDown(KeyCode.E))
                {
                    if (item.interactionType == InteractableItem.InteractionType.PickupAndMove)
                    {
                        GrabObject(item);
                    }
                    else
                    {
                        item.Interact();
                    }
                }
                return;
            }
        }

        if (promptUI != null)
        {
            promptUI.text = "";
        }
    }

    void GrabObject(InteractableItem item)
    {
        heldItem = item;
        originalY = item.transform.position.y;
        holdDistance = Vector3.Distance(transform.position, item.transform.position);
        holdDistance = Mathf.Clamp(holdDistance, 1.2f, 3.2f);

        // Temporarily disable colliders on the held item so it doesn't push the player around
        heldColliders = heldItem.GetComponentsInChildren<Collider>();
        foreach (Collider col in heldColliders)
        {
            col.enabled = false;
        }
    }

    void HandleHeldObject()
    {
        if (promptUI != null)
        {
            promptUI.text = "[E] Place Down \n [R] Rotate \n [Scroll] Distance";
        }

        // Adjust distance with Mouse Scroll Wheel
        float scroll = Input.GetAxis("Mouse ScrollWheel");
        if (Mathf.Abs(scroll) > 0.01f)
        {
            holdDistance = Mathf.Clamp(holdDistance + scroll * 1.5f, 1.0f, 3.5f);
        }

        // Calculate target position in front of the camera
        Vector3 targetPos = transform.position + transform.forward * holdDistance;

        // Keep large floor furniture at floor height, or clamp props above the floor
        if (heldItem.keepFloorHeight)
        {
            targetPos.y = originalY;
        }
        else
        {
            targetPos.y = Mathf.Clamp(targetPos.y, 0.05f, 2.6f);
        }

        heldItem.transform.position = Vector3.Lerp(heldItem.transform.position, targetPos, Time.deltaTime * moveSmoothSpeed);

        // Rotate object 45 degrees when pressing R
        if (Input.GetKeyDown(KeyCode.R))
        {
            heldItem.transform.Rotate(0f, 45f, 0f, Space.World);
        }

        // Drop / Place the object when pressing E again
        if (Input.GetKeyDown(KeyCode.E))
        {
            foreach (Collider col in heldColliders)
            {
                if (col != null) col.enabled = true;
            }
            heldItem = null;
        }
    }
}