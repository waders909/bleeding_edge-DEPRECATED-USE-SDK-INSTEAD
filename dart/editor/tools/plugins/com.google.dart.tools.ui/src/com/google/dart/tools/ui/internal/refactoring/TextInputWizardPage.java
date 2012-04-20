/*
 * Copyright (c) 2012, the Dart project authors.
 * 
 * Licensed under the Eclipse Public License v1.0 (the "License"); you may not use this file except
 * in compliance with the License. You may obtain a copy of the License at
 * 
 * http://www.eclipse.org/legal/epl-v10.html
 * 
 * Unless required by applicable law or agreed to in writing, software distributed under the License
 * is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
 * or implied. See the License for the specific language governing permissions and limitations under
 * the License.
 */
package com.google.dart.tools.ui.internal.refactoring;

import com.google.dart.tools.ui.internal.dialogs.TextFieldNavigationHandler;

import org.eclipse.core.runtime.Assert;
import org.eclipse.ltk.core.refactoring.RefactoringStatus;
import org.eclipse.ltk.ui.refactoring.UserInputWizardPage;
import org.eclipse.swt.SWT;
import org.eclipse.swt.events.ModifyEvent;
import org.eclipse.swt.events.ModifyListener;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Text;

/**
 * A TextInputWizardPage is a simple UserInputWizardPage with facilities to create a text input
 * field and validate its contents. The text is assumed to be a Dart identifier, hence CamelCase
 * word jumping is installed.
 * 
 * @coverage dart.editor.ui.refactoring.ui
 */
public abstract class TextInputWizardPage extends UserInputWizardPage {

  private final String fInitialValue;
  private Text fTextField;

  public static final String PAGE_NAME = "TextInputPage";//$NON-NLS-1$

  /**
   * Creates a new text input page.
   * 
   * @param isLastUserPage <code>true</code> if this page is the wizard's last user input page.
   *          Otherwise <code>false</code>.
   */
  public TextInputWizardPage(String description, boolean isLastUserPage) {
    this(description, isLastUserPage, ""); //$NON-NLS-1$
  }

  /**
   * Creates a new text input page.
   * 
   * @param isLastUserPage <code>true</code> if this page is the wizard's last user input page.
   *          Otherwise <code>false</code>
   * @param initialValue the initial value
   */
  public TextInputWizardPage(String description, boolean isLastUserPage, String initialValue) {
    super(PAGE_NAME);
    Assert.isNotNull(initialValue);
    setDescription(description);
    fInitialValue = initialValue;
  }

  @Override
  public void dispose() {
    fTextField = null;
  }

  /**
   * Returns the initial value.
   * 
   * @return the initial value
   */
  public String getInitialValue() {
    return fInitialValue;
  }

  @Override
  public void setVisible(boolean visible) {
    if (visible) {
      textModified(getText());
    }
    super.setVisible(visible);
    if (visible && fTextField != null) {
      fTextField.setFocus();
    }
  }

  protected Text createTextInputField(Composite parent) {
    return createTextInputField(parent, SWT.BORDER);
  }

  protected Text createTextInputField(Composite parent, int style) {
    fTextField = new Text(parent, style);
    fTextField.addModifyListener(new ModifyListener() {
      @Override
      public void modifyText(ModifyEvent e) {
        textModified(getText());
      }
    });
    fTextField.setText(fInitialValue);
    TextFieldNavigationHandler.install(fTextField);
    return fTextField;
  }

  /**
   * Returns the content of the text input field.
   * 
   * @return the content of the text input field. Returns <code>null</code> if not text input field
   *         has been created
   */
  protected String getText() {
    if (fTextField == null) {
      return null;
    }
    return fTextField.getText();
  }

  /**
   * Returns the text entry field
   * 
   * @return the text entry field
   */
  protected Text getTextField() {
    return fTextField;
  }

  /**
   * Returns whether an empty string is a valid input. Typically it is not, because the user is
   * required to provide some information e.g. a new type name etc.
   * 
   * @return <code>true</code> iff an empty string is valid
   */
  protected boolean isEmptyInputValid() {
    return false;
  }

  /**
   * Returns whether the initial input is valid. Typically it is not, because the user is required
   * to provide some information e.g. a new type name etc.
   * 
   * @return <code>true</code> iff the input provided at initialization is valid
   */
  protected boolean isInitialInputValid() {
    return false;
  }

  /**
   * Subclasses can override if they want to restore the message differently. This implementation
   * calls <code>setMessage(null)</code>, which clears the message thus exposing the description.
   */
  protected void restoreMessage() {
    setMessage(null);
  }

  /**
   * Sets the new text for the text field. Does nothing if the text field has not been created.
   * 
   * @param text the new value
   */
  protected void setText(String text) {
    if (fTextField == null) {
      return;
    }
    fTextField.setText(text);
  }

  /**
   * Checks the page's state and issues a corresponding error message. The page validation is
   * computed by calling <code>validatePage</code>.
   */
  protected void textModified(String text) {
    if (!isEmptyInputValid() && "".equals(text)) { //$NON-NLS-1$
      setPageComplete(false);
      setErrorMessage(null);
      restoreMessage();
      return;
    }
    if (!isInitialInputValid() && fInitialValue.equals(text)) {
      setPageComplete(false);
      setErrorMessage(null);
      restoreMessage();
      return;
    }

    RefactoringStatus status = validateTextField(text);
    if (status == null) {
      status = new RefactoringStatus();
    }
    setPageComplete(status);
  }

  /**
   * Performs input validation. Returns a <code>RefactoringStatus</code> which describes the result
   * of input validation. <code>Null<code> is interpreted
   * as no error.
   */
  protected RefactoringStatus validateTextField(String text) {
    return null;
  }
}
