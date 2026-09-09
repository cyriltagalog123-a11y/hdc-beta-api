# Managing HDC knowledge

Open **Knowledge Base → Manage Knowledge** while signed in with an Owner, Super Admin, or Admin account.

## Everyday tasks

| Task | How to do it |
| --- | --- |
| Add a guide | Choose **New guide**, fill in the title, category, summary, context, and at least one step. Choose **Save draft**. |
| Find a guide | Search by title, summary, tag, link name, or guide ID. Filter by category and working status. **Load more guides** continues through larger libraries. |
| Edit or update | Choose **Edit guide**. Edit the fields, preview the result, then save a draft or send it for review. |
| Reorder steps | Use a step's up/down arrows. **Add step** adds another instruction; remove deletes a step with an **Undo** option. Each guide supports 1–20 distinct steps of up to 700 characters. |
| Move to another category | Choose **Move**, select the destination, then **Save move**. A published guide gets a review copy; publish it to make the new category public. |
| Publish | Owner or Super Admin opens the editor, chooses **Publish…**, and confirms. This updates the public guide and, if enabled, Nexus retrieval. |
| Remove a published guide | Choose **More → Archive guide** and confirm. The public guide disappears, while its permanent link and history are retained. |
| Restore an archived guide | Filter to **Archived**, choose **Restore guide**, and confirm. For a previously published guide, its last published version becomes visible again; working changes stay in review. |
| Delete an unpublished draft | Choose **More → Delete draft** and confirm. This permanently deletes a never-published draft and its draft history. |
| See previous changes | Choose **More → Version history**. Published versions are marked; change notes explain saved edits. |

Saving a draft or sending it for review does not update an already published guide. The library displays both the working version and public version so pending changes are clear. Published links cannot be renamed. Archiving and publishing require Owner or Super Admin authority; Admin can author and review.

The editor previews your current unsaved content without publishing or making a network write. In-app back navigation asks before discarding edits. Save drafts before refreshing or closing the browser. A failed save keeps your edits in the open editor. A version-conflict message means another author saved first; preserve your changes and reopen the latest guide before applying them.

The six existing categories remain available. This update does not require a database migration, external CMS, or new dependency.

## Optional next improvements for discussion

- Configurable categories: create, rename, order, and retire categories, with a destination required before removing one that contains guides.
- Bulk import with a preview: validate a CSV/JSON batch, flag duplicates, and import as drafts for review.
- A content review queue: bring reader feedback and aging guides into one place so the next improvements follow actual gaps.

These are proposals, not included features or enabled services.
