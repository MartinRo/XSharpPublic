﻿using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.ComponentModel.Composition;
using System.Runtime.InteropServices;
using Microsoft.VisualStudio.Language.Intellisense;
using Microsoft.VisualStudio.Text;
using Microsoft.VisualStudio.Text.Editor;
using Microsoft.VisualStudio.Utilities;
using Microsoft.VisualStudio.Editor;
using Microsoft.VisualStudio.Text.Operations;
using Microsoft.VisualStudio;
using Microsoft.VisualStudio.TextManager.Interop;
using Microsoft.VisualStudio.OLE.Interop;

namespace XSharp.Project
{
    internal class XSharpParameter : IParameter
    {
        public string Documentation { get; private set; }
        public Span Locus { get; private set; }
        public string Name { get; private set; }
        public ISignature Signature { get; private set; }
        public Span PrettyPrintedLocus { get; private set; }


        public XSharpParameter(string documentation, Span locus, string name, ISignature signature)
        {
            Documentation = documentation;
            Locus = locus;
            Name = name;
            Signature = signature;
        }
    }


    internal class XSharpSignature : ISignature
    {
        private ITextBuffer m_subjectBuffer;
        private IParameter m_currentParameter;
        private string m_content;
        private string m_documentation;
        private ITrackingSpan m_applicableToSpan;
        private ReadOnlyCollection<IParameter> m_parameters;
        private string m_printContent;

        internal XSharpSignature(ITextBuffer subjectBuffer, string content, string doc, ReadOnlyCollection<IParameter> parameters)
        {
            m_subjectBuffer = subjectBuffer;
            m_content = content;
            m_documentation = doc;
            m_parameters = parameters;
            m_subjectBuffer.Changed += new EventHandler<TextContentChangedEventArgs>(OnSubjectBufferChanged);
        }

        public event EventHandler<CurrentParameterChangedEventArgs> CurrentParameterChanged;

        public IParameter CurrentParameter
        {
            get { return m_currentParameter; }

            internal set
            {
                if (m_currentParameter != value)
                {
                    IParameter prevCurrentParameter = m_currentParameter;
                    m_currentParameter = value;
                    this.RaiseCurrentParameterChanged(prevCurrentParameter, m_currentParameter);
                }
            }
        }

        private void RaiseCurrentParameterChanged(IParameter prevCurrentParameter, IParameter newCurrentParameter)
        {
            EventHandler<CurrentParameterChangedEventArgs> tempHandler = this.CurrentParameterChanged;
            if (tempHandler != null)
            {
                tempHandler(this, new CurrentParameterChangedEventArgs(prevCurrentParameter, newCurrentParameter));
            }
        }

        internal void ComputeCurrentParameter()
        {
            if (Parameters.Count == 0)
            {
                this.CurrentParameter = null;
                return;
            }

            //the number of commas in the string is the index of the current parameter
            string sigText = ApplicableToSpan.GetText(m_subjectBuffer.CurrentSnapshot);

            int currentIndex = 0;
            int commaCount = 0;
            while (currentIndex < sigText.Length)
            {
                int commaIndex = sigText.IndexOf(',', currentIndex);
                if (commaIndex == -1)
                {
                    break;
                }
                commaCount++;
                currentIndex = commaIndex + 1;
            }

            if (commaCount < Parameters.Count)
            {
                this.CurrentParameter = Parameters[commaCount];
            }
            else
            {
                //too many commas, so use the last parameter as the current one.
                //this.CurrentParameter = Parameters[Parameters.Count - 1];
            }
        }

        internal void OnSubjectBufferChanged(object sender, TextContentChangedEventArgs e)
        {
            this.ComputeCurrentParameter();
        }

        public ITrackingSpan ApplicableToSpan
        {
            get { return (m_applicableToSpan); }
            internal set { m_applicableToSpan = value; }
        }

        public string Content
        {
            get { return (m_content); }
            internal set { m_content = value; }
        }

        public string Documentation
        {
            get { return (m_documentation); }
            internal set { m_documentation = value; }
        }

        public ReadOnlyCollection<IParameter> Parameters
        {
            get { return (m_parameters); }
            internal set { m_parameters = value; }
        }

        public string PrettyPrintedContent
        {
            get { return (m_printContent); }
            internal set { m_printContent = value; }
        }


    }

    internal class XSharpSignatureHelpSource : ISignatureHelpSource
    {

        private ITextBuffer m_textBuffer;
        //private ISignatureHelpSession m_session;

        public XSharpSignatureHelpSource(ITextBuffer textBuffer)
        {
            m_textBuffer = textBuffer;
        }

        public void AugmentSignatureHelpSession(ISignatureHelpSession session, IList<ISignature> signatures)
        {
            ITextSnapshot snapshot = m_textBuffer.CurrentSnapshot;
            int position = session.GetTriggerPoint(m_textBuffer).GetPosition(snapshot);
            int start = (int)session.Properties["Start"];
            int length = (int)session.Properties["Length"];

            ITrackingSpan applicableToSpan = m_textBuffer.CurrentSnapshot.CreateTrackingSpan(
             new Span(start, length), SpanTrackingMode.EdgeInclusive, 0);

            object elt = session.Properties["Element"];
            if ( elt is XSharpModel.XElement)
            {
                XSharpModel.XElement element = elt as XSharpModel.XElement;
                signatures.Add(CreateSignature(m_textBuffer, element.Prototype, "", applicableToSpan));
                //
                if (elt is XSharpModel.XTypeMember)
                {
                    XSharpModel.XTypeMember xMember = elt as XSharpModel.XTypeMember;
                    List<XSharpModel.XTypeMember> namesake = xMember.Namesake();
                    foreach (var member in namesake)
                    {
                        signatures.Add(CreateSignature(m_textBuffer, member.Prototype, "", applicableToSpan));
                    }
                    //
                }
            }

        }

        private XSharpSignature CreateSignature(ITextBuffer textBuffer, string methodSig, string methodDoc, ITrackingSpan span)
        {
            XSharpSignature sig = new XSharpSignature(textBuffer, methodSig, methodDoc, null);
            // Moved : Done in the XSharpSignature constructor
            //textBuffer.Changed += new EventHandler<TextContentChangedEventArgs>(sig.OnSubjectBufferChanged);

            //find the parameters in the method signature (expect methodname(one, two)
            string[] pars = methodSig.Split(new char[] { '(', ',', ')' });
            List<IParameter> paramList = new List<IParameter>();

            int locusSearchStart = 0;
            for (int i = 1; i < pars.Length; i++)
            {
                string param = pars[i].Trim();
                if (string.IsNullOrEmpty(param))
                    continue;

                //find where this parameter is located in the method signature
                int locusStart = methodSig.IndexOf(param, locusSearchStart);
                if (locusStart >= 0)
                {
                    Span locus = new Span(locusStart, param.Length);
                    locusSearchStart = locusStart + param.Length;
                    // paramList.Add(new XSharpParameter("Documentation for the parameter.", locus, param, sig));
                    paramList.Add(new XSharpParameter("", locus, param, sig));
                }
            }

            sig.Parameters = new ReadOnlyCollection<IParameter>(paramList);
            sig.ApplicableToSpan = span;
            sig.ComputeCurrentParameter();
            return sig;
        }

        public ISignature GetBestMatch(ISignatureHelpSession session)
        {
            if (session.Signatures.Count > 0)
            {
                ITrackingSpan applicableToSpan = session.Signatures[0].ApplicableToSpan;
                string text = applicableToSpan.GetText(applicableToSpan.TextBuffer.CurrentSnapshot);

                return session.Signatures[0];
            }
            return null;
        }

        private bool m_isDisposed;
        public void Dispose()
        {
            if (!m_isDisposed)
            {
                GC.SuppressFinalize(this);
                m_isDisposed = true;
            }
        }
    }
}