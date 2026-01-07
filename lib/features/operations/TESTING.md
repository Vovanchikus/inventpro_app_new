# Operations Feature — Manual Test Checklist

Use this list before each release to make sure the MVVM-driven "История" tab behaves correctly end-to-end.

1. **Initial load**

   - Launch the app, switch to the "История" tab (now powered by `OperationsScreen`).
   - Confirm a loading indicator appears, then grouped history cards render once the API responds. If the API returns no data, you should see the empty-state message.

2. **Refresh & errors**

   - Pull to refresh and ensure the spinner appears and the data reloads.
   - Temporarily disable the network to trigger the error block, then restore connectivity and reload to verify recovery.

3. **Filters**

   - Change Year / Operation Type / Counteragent dropdowns individually and in combination; ensure the list updates and the `Сбросить` button clears all filters.
   - Validate that counteragent chips in the summary reflect the signed totals ($+$ for inbound, $-$ for outbound).

4. **Signed quantities**

   - Inspect several cards and ensure incoming operations show `+` and green tone, outbound show `-` and red tone. Compare with the backend `operation.type.id` reference list.

5. **Navigation & stability**
   - Navigate away from the tab and return to ensure state persists only through the ViewModel.
   - Use the system back button to leave the tab and verify no crashes occur.

Document the results in your test notes or ticket before release.
